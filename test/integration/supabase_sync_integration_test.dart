/// Integration tests against a REAL local Supabase stack.
///
/// These exist because every field bug in the sync feature so far lived in
/// the gap between the client's model of the remote and the actual Postgres:
/// server triggers rewriting timestamps, CHECK constraints satisfied on only
/// one code path, missing columns, RLS chain queries, response-row caps.
/// Unit tests against fakes cannot catch that class of bug by construction.
///
/// ## Running locally
/// ```
///   supabase start                # applies migrations + seed.sql
///   supabase status -o env        # note API_URL, ANON_KEY, SERVICE_ROLE_KEY
///   SUPABASE_TEST_URL=http://127.0.0.1:54321 \
///   SUPABASE_TEST_ANON_KEY=... \
///   SUPABASE_TEST_SERVICE_ROLE_KEY=... \
///     flutter test test/integration --tags integration
/// ```
/// Without the env vars the whole suite is skipped, so a plain
/// `flutter test` stays green on machines without the stack.
@Tags(['integration'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:repertoire_coach/data/datasources/remote/remote_marker_data_source.dart';
import 'package:repertoire_coach/data/models/choir_member_model.dart';
import 'package:repertoire_coach/data/models/marker_set_model.dart';

final _url = Platform.environment['SUPABASE_TEST_URL'];
final _anonKey = Platform.environment['SUPABASE_TEST_ANON_KEY'];
final _serviceKey = Platform.environment['SUPABASE_TEST_SERVICE_ROLE_KEY'];

const _uuid = Uuid();

void main() {
  final unavailable = _url == null || _anonKey == null || _serviceKey == null;

  group(
    'Supabase integration',
    skip: unavailable
        ? 'requires a local Supabase stack — see file header'
        : false,
    () {
      // Service-role client: bypasses RLS; used for seeding and raw asserts.
      late SupabaseClient service;
      // Per-user clients: real RLS perspective.
      late SupabaseClient owner;
      late SupabaseClient member;
      late SupabaseClient outsider;
      late String ownerId, memberId, outsiderId;
      // Seeded content chain.
      late String choirId, concertId, songId, trackId;

      /// Creates a confirmed auth user + matching public.users row and
      /// returns a signed-in client for them.
      Future<(SupabaseClient, String)> createUser(String tag) async {
        final email = 'it-$tag-${_uuid.v4().substring(0, 8)}@test.local';
        const password = 'integration-test-password';
        final created = await service.auth.admin.createUser(
          AdminUserAttributes(
            email: email,
            password: password,
            emailConfirm: true,
          ),
        );
        final id = created.user!.id;
        await service.from('users').upsert({'id': id, 'email': email});
        final client = SupabaseClient(_url!, _anonKey!);
        await client.auth.signInWithPassword(email: email, password: password);
        return (client, id);
      }

      setUpAll(() async {
        service = SupabaseClient(_url!, _serviceKey!);
        (owner, ownerId) = await createUser('owner');
        (member, memberId) = await createUser('member');
        (outsider, outsiderId) = await createUser('outsider');

        // Seed the visibility chain choir -> concert -> song -> track with
        // both owner and member as choir members (matching app behavior).
        choirId = _uuid.v4();
        concertId = _uuid.v4();
        songId = _uuid.v4();
        trackId = _uuid.v4();
        await service.from('choirs').insert(
            {'id': choirId, 'name': 'IT choir', 'owner_id': ownerId});
        await service.from('choir_members').insert([
          {'choir_id': choirId, 'user_id': ownerId},
          {'choir_id': choirId, 'user_id': memberId},
        ]);
        await service.from('concerts').insert({
          'id': concertId,
          'choir_id': choirId,
          'name': 'IT concert',
          'concert_date': '2026-12-24',
        });
        await service.from('songs').insert(
            {'id': songId, 'concert_id': concertId, 'title': 'IT song'});
        await service.from('tracks').insert({
          'id': trackId,
          'song_id': songId,
          'name': 'Soprano',
          'audio_url': 'https://example.invalid/a.mp3',
          'storage_path': 'it/a.mp3',
          'duration_ms': 1000,
        });
      });

      tearDownAll(() async {
        // Cascades from choirs cover the content chain.
        await service.from('choirs').delete().eq('id', choirId);
        for (final id in [ownerId, memberId, outsiderId]) {
          await service.auth.admin.deleteUser(id);
        }
        await owner.dispose();
        await member.dispose();
        await outsider.dispose();
        await service.dispose();
      });

      MarkerSetModel makeSet({
        required String id,
        required DateTime updatedAt,
        String name = 'IT set',
        bool isTimeSynced = true,
        String markersJson = '[]',
        bool isShared = true,
      }) {
        return MarkerSetModel(
          id: id,
          trackId: trackId,
          name: name,
          isShared: isShared,
          isTimeSynced: isTimeSynced,
          createdByUserId: ownerId,
          createdAt: updatedAt,
          updatedAt: updatedAt,
          markersJson: markersJson,
        );
      }

      // ------------------------------------------------------------------
      // 1. Schema drift: model JSON keys vs real table columns.
      //    Would have caught: tracks missing updated_at entirely.
      // ------------------------------------------------------------------
      test('model toJson keys exist as columns (schema drift guard)',
          () async {
        Future<Set<String>> columnsOf(String table) async {
          final rows = await service
              .rpc('table_columns', params: {'p_table': table}) as List;
          return rows
              .map((r) => (r as Map)['column_name'] as String)
              .toSet();
        }

        final markerSetKeys =
            makeSet(id: _uuid.v4(), updatedAt: DateTime.now().toUtc())
                .toJson()
                .keys
                .toSet();
        final markerSetCols = await columnsOf('marker_sets');
        expect(markerSetCols.containsAll(markerSetKeys), true,
            reason: 'marker_sets is missing columns the client sends: '
                '${markerSetKeys.difference(markerSetCols)}');

        final memberKeys = ChoirMemberModel(
          choirId: choirId,
          userId: memberId,
          joinedAt: DateTime.now().toUtc(),
          updatedAt: DateTime.now().toUtc(),
        ).toJson().keys.toSet();
        final memberCols = await columnsOf('choir_members');
        expect(memberCols.containsAll(memberKeys), true,
            reason: 'choir_members is missing columns the client sends: '
                '${memberKeys.difference(memberCols)}');

        // Columns the sync design depends on, per table.
        for (final table in [
          'choirs', 'choir_members', 'concerts', 'songs', 'tracks',
          'marker_sets', 'favorite_tracks',
        ]) {
          final cols = await columnsOf(table);
          expect(cols.contains('deleted'), true,
              reason: '$table lacks the tombstone column');
          expect(cols.contains('updated_at'), true,
              reason: '$table lacks updated_at (conflict resolution '
                  'is impossible without it)');
        }
      });

      // ------------------------------------------------------------------
      // 2. updated_at is client-authoritative edit time.
      //    Would have caught: the BEFORE UPDATE trigger + push-time stamping
      //    that made "newest wins" compare push times, silently overwriting
      //    newer edits with older ones.
      // ------------------------------------------------------------------
      test('remote updated_at equals the model edit time, not push time',
          () async {
        final id = _uuid.v4();
        final remote = RemoteMarkerDataSource(owner);
        final tCreate = DateTime.utc(2026, 6, 1, 10, 0, 0);
        await remote.createMarkerSet(makeSet(id: id, updatedAt: tCreate));

        final tEdit = DateTime.utc(2026, 6, 2, 11, 30, 0);
        await remote.updateMarkerSet(
            makeSet(id: id, updatedAt: tEdit, name: 'edited'));

        final row = await service
            .from('marker_sets')
            .select('updated_at')
            .eq('id', id)
            .single();
        final stored = DateTime.parse(row['updated_at'] as String).toUtc();
        expect(stored, tEdit,
            reason: 'updated_at was rewritten server-side or stamped with '
                'push time — a server trigger or datasource regression has '
                'reintroduced the conflict-resolution bug');
      });

      // ------------------------------------------------------------------
      // 3. is_time_synced CHECK constraint holds on the SYNC push path.
      //    Would have caught: the constraint being satisfied only by the
      //    repositories' (now removed) inline path, leaving adapter pushes
      //    permanently rejected and items stuck unsynced forever.
      // ------------------------------------------------------------------
      test('sync-path push with a stale is_time_synced flag is accepted',
          () async {
        final id = _uuid.v4();
        final remote = RemoteMarkerDataSource(owner);
        const timedPayload =
            '[{"id":"m1","label":"Verse","position_ms":1500,"display_order":0}]';

        // Deliberately stale flag: payload is fully timed, flag says false.
        await remote.createMarkerSet(makeSet(
          id: id,
          updatedAt: DateTime.utc(2026, 6, 1),
          isTimeSynced: false,
          markersJson: timedPayload,
        ));

        final row = await service
            .from('marker_sets')
            .select('is_time_synced')
            .eq('id', id)
            .single();
        expect(row['is_time_synced'], true,
            reason: 'the datasource must recompute the flag from the payload');
      });

      // ------------------------------------------------------------------
      // 4. Deletion round-trips as a tombstone carrying its deletion time.
      // ------------------------------------------------------------------
      test('delete produces a tombstone with the deletion timestamp',
          () async {
        final id = _uuid.v4();
        final remote = RemoteMarkerDataSource(owner);
        await remote.createMarkerSet(
            makeSet(id: id, updatedAt: DateTime.utc(2026, 6, 1)));

        final tDelete = DateTime.utc(2026, 6, 3, 9, 0, 0);
        await remote.deleteMarkerSet(id, tDelete);

        final sets = await remote.getMarkerSetsForUser(ownerId);
        final tombstone = sets.where((s) => s.id == id).toList();
        expect(tombstone.length, 1,
            reason: 'tombstones must be returned by getAllRemote, or '
                'deletions can never propagate');
        expect(tombstone.first.deleted, true);
        expect(tombstone.first.updatedAt.toUtc(), tDelete);
      });

      // ------------------------------------------------------------------
      // 5. RLS visibility through the membership chain.
      // ------------------------------------------------------------------
      test('choir member sees shared sets; outsider does not', () async {
        final id = _uuid.v4();
        await RemoteMarkerDataSource(owner).createMarkerSet(
            makeSet(id: id, updatedAt: DateTime.utc(2026, 6, 1)));

        final memberSets =
            await RemoteMarkerDataSource(member).getMarkerSetsForUser(memberId);
        expect(memberSets.any((s) => s.id == id), true,
            reason: 'choir member must see shared marker sets');

        final outsiderSets = await RemoteMarkerDataSource(outsider)
            .getMarkerSetsForUser(outsiderId);
        expect(outsiderSets.any((s) => s.id == id), false,
            reason: 'RLS must hide the set from non-members');
      });

      // ------------------------------------------------------------------
      // 6. Response caps: getAllRemote must return EVERYTHING.
      //    PostgREST caps responses at 1000 rows by default; a truncated
      //    read silently delays sync of the tail indefinitely.
      //    Fixed by fetchAllRows/.range() paging in the remote datasources
      //    (lib/data/datasources/remote/postgrest_pagination.dart).
      // ------------------------------------------------------------------
      test(
        'getMarkerSetsForUser returns more than 1000 rows',
        () async {
          final rows = List.generate(
              1100,
              (i) => {
                    'id': _uuid.v4(),
                    'track_id': trackId,
                    'name': 'bulk-$i',
                    'is_shared': true,
                    'is_time_synced': true,
                    'created_by_user_id': ownerId,
                    'markers_json': [],
                  });
          for (var i = 0; i < rows.length; i += 200) {
            await service.from('marker_sets').insert(
                rows.sublist(i, (i + 200).clamp(0, rows.length)));
          }

          final sets = await RemoteMarkerDataSource(owner)
              .getMarkerSetsForUser(ownerId);
          expect(sets.length, greaterThanOrEqualTo(1100));
        },
      );
    },
  );
}
