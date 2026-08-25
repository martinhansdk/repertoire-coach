import 'package:flutter_test/flutter_test.dart';
import 'package:repertoire_coach/data/datasources/remote/postgrest_pagination.dart';

/// A fake backend of [total] rows that answers range requests the way
/// PostgREST does, optionally enforcing a server-side row cap below the
/// requested page size (Supabase's `max-rows`).
class _FakeBackend {
  final int total;
  final int? serverCap;
  final List<(int, int)> calls = [];

  _FakeBackend(this.total, {this.serverCap});

  Future<List<dynamic>> fetch(int from, int to) async {
    calls.add((from, to));
    var upper = to < (total - 1) ? to : total - 1;
    if (serverCap != null && (upper - from + 1) > serverCap!) {
      upper = from + serverCap! - 1;
    }
    if (from >= total) return [];
    return [
      for (var i = from; i <= upper; i++) {'id': 'row-$i'}
    ];
  }
}

void main() {
  group('fetchAllRows', () {
    test('returns everything across multiple pages, in order', () async {
      final backend = _FakeBackend(2500);
      final rows = await _fetchAllFrom(backend);

      expect(rows.length, 2500);
      expect(rows.first['id'], 'row-0');
      expect(rows.last['id'], 'row-2499');
      // Pages requested: 0-999, 1000-1999, 2000-2999.
      expect(backend.calls, [(0, 999), (1000, 1999), (2000, 2999)]);
    });

    test('REGRESSION: more rows than one PostgREST response can carry',
        () async {
      // The exact field condition: >1000 rows, previously silently truncated
      // to the first 1000 by the server with no error.
      final backend = _FakeBackend(1100);
      final rows = await _fetchAllFrom(backend);
      expect(rows.length, 1100);
    });

    test('total an exact multiple of the page size terminates', () async {
      final backend = _FakeBackend(2000);
      final rows = await _fetchAllFrom(backend);
      expect(rows.length, 2000);
      // A full final page can't prove completion; one extra (empty) probe.
      expect(backend.calls.length, 3);
    });

    test('fewer rows than a page -> single request', () async {
      final backend = _FakeBackend(7);
      final rows = await _fetchAllFrom(backend);
      expect(rows.length, 7);
      expect(backend.calls.length, 1);
    });

    test('empty result -> single request, empty list', () async {
      final backend = _FakeBackend(0);
      final rows = await _fetchAllFrom(backend);
      expect(rows, isEmpty);
      expect(backend.calls.length, 1);
    });

    test(
        'DOCUMENTED LIMIT: a server row cap below pageSize truncates — '
        'pageSize must never exceed the PostgREST max-rows setting', () async {
      final backend = _FakeBackend(900, serverCap: 500);
      final rows = await _fetchAllFrom(backend); // pageSize 1000 > cap 500
      // The loop sees a 500-row "short" page and stops: this is the failure
      // mode you get if max-rows is lowered without lowering pageSize.
      expect(rows.length, 500);

      // Setting pageSize at or below the cap restores completeness.
      final backend2 = _FakeBackend(900, serverCap: 500);
      final rows2 = await fetchAllRows(backend2.fetch, pageSize: 500);
      expect(rows2.length, 900);
    });
  });

  group('fetchAllRowsChunkedIn', () {
    test('splits values into bounded chunks and merges results in order',
        () async {
      final ids = List.generate(250, (i) => 'id-$i');
      final seenChunks = <List<String>>[];

      final rows = await fetchAllRowsChunkedIn(ids, (chunk) async {
        seenChunks.add(chunk);
        return [
          for (final id in chunk) {'id': id}
        ];
      });

      expect(seenChunks.map((c) => c.length).toList(), [100, 100, 50]);
      expect(rows.length, 250);
      expect(rows.first['id'], 'id-0');
      expect(rows.last['id'], 'id-249');
    });

    test('empty id list -> no requests at all', () async {
      var calls = 0;
      final rows = await fetchAllRowsChunkedIn(<String>[], (chunk) async {
        calls++;
        return [];
      });
      expect(rows, isEmpty);
      expect(calls, 0);
    });

    test('composes with fetchAllRows: each chunk is itself fully paged',
        () async {
      // 3 chunks; the middle chunk's result set exceeds one page.
      final ids = List.generate(220, (i) => 'id-$i');
      final rows = await fetchAllRowsChunkedIn(ids, (chunk) {
        final rowsPerId = chunk.contains('id-150') ? 15 : 1;
        final backend = _FakeBackend(chunk.length * rowsPerId);
        return fetchAllRows(backend.fetch);
      });
      // chunk1: 100 rows, chunk2: 1500 rows (paged: 1000+500), chunk3: 20.
      expect(rows.length, 100 + 1500 + 20);
    });
  });
}

/// Small shim so the default-pageSize call sites read cleanly above.
Future<List<Map<String, dynamic>>> _fetchAllFrom(_FakeBackend b) =>
    fetchAllRows(b.fetch);
