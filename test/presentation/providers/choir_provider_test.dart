import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:repertoire_coach/data/datasources/local/database.dart' as db;
import 'package:repertoire_coach/data/datasources/local/local_choir_data_source.dart';
import 'package:repertoire_coach/data/repositories/choir_repository_impl.dart';
import 'package:repertoire_coach/domain/entities/choir.dart';
import 'package:repertoire_coach/domain/repositories/choir_repository.dart';
import 'package:repertoire_coach/presentation/providers/choir_provider.dart';
import 'package:repertoire_coach/presentation/providers/concert_provider.dart';

import 'choir_provider_test.mocks.dart';

@GenerateMocks([ChoirRepository])
void main() {
  group('Choir Providers', () {
    test('localChoirDataSourceProvider returns LocalChoirDataSource', () {
      final container = ProviderContainer();
      expect(container.read(localChoirDataSourceProvider),
          isA<LocalChoirDataSource>());
    });

    test('choirRepositoryProvider returns ChoirRepository', () {
      final container = ProviderContainer();
      expect(
          container.read(choirRepositoryProvider), isA<ChoirRepository>());
    });

    test('currentUserIdProvider returns a default user ID', () {
      final container = ProviderContainer();
      expect(container.read(currentUserIdProvider), 'user1');
    });

    group('choirsProvider', () {
      test('returns a list of choirs on success', () async {
        final mockRepository = MockChoirRepository();
        final choirs = [
          Choir(id: 'c1', name: 'Choir 1', ownerId: 'u1', createdAt: DateTime.now()),
        ];
        when(mockRepository.getChoirs('user1'))
            .thenAnswer((_) async => choirs);

        final container = ProviderContainer(
          overrides: [
            choirRepositoryProvider.overrideWithValue(mockRepository),
          ],
        );

        final result = await container.read(choirsProvider.future);
        expect(result, choirs);
      });

      test('returns an empty list on error', () async {
        final mockRepository = MockChoirRepository();
        when(mockRepository.getChoirs('user1'))
            .thenThrow(Exception('test error'));

        final container = ProviderContainer(
          overrides: [
            choirRepositoryProvider.overrideWithValue(mockRepository),
          ],
        );

        final result = await container.read(choirsProvider.future);
        expect(result, []);
      });
    });

    group('choirByIdProvider', () {
      test('returns a choir on success', () async {
        final mockRepository = MockChoirRepository();
        final choir = Choir(id: 'c1', name: 'Choir 1', ownerId: 'u1', createdAt: DateTime.now());
        when(mockRepository.getChoirById('c1'))
            .thenAnswer((_) async => choir);

        final container = ProviderContainer(
          overrides: [
            choirRepositoryProvider.overrideWithValue(mockRepository),
          ],
        );

        final result = await container.read(choirByIdProvider('c1').future);
        expect(result, choir);
      });

      test('returns null if choir not found', () async {
        final mockRepository = MockChoirRepository();
        when(mockRepository.getChoirById('c1'))
            .thenAnswer((_) async => null);

        final container = ProviderContainer(
          overrides: [
            choirRepositoryProvider.overrideWithValue(mockRepository),
          ],
        );

        final result = await container.read(choirByIdProvider('c1').future);
        expect(result, isNull);
      });
    });

    group('choirMembersProvider', () {
      test('returns a list of member IDs on success', () async {
        final mockRepository = MockChoirRepository();
        final memberIds = ['u1', 'u2'];
        when(mockRepository.getMembers('c1'))
            .thenAnswer((_) async => memberIds);

        final container = ProviderContainer(
          overrides: [
            choirRepositoryProvider.overrideWithValue(mockRepository),
          ],
        );

        final result = await container.read(choirMembersProvider('c1').future);
        expect(result, memberIds);
      });
    });

    group('isChoirOwnerProvider', () {
      test('returns true if current user is owner', () async {
        final mockRepository = MockChoirRepository();
        when(mockRepository.isOwner('c1', 'user1'))
            .thenAnswer((_) async => true);

        final container = ProviderContainer(
          overrides: [
            choirRepositoryProvider.overrideWithValue(mockRepository),
          ],
        );

        final result = await container.read(isChoirOwnerProvider('c1').future);
        expect(result, isTrue);
      });

      test('returns false if current user is not owner', () async {
        final mockRepository = MockChoirRepository();
        when(mockRepository.isOwner('c1', 'user1'))
            .thenAnswer((_) async => false);

        final container = ProviderContainer(
          overrides: [
            choirRepositoryProvider.overrideWithValue(mockRepository),
          ],
        );

        final result = await container.read(isChoirOwnerProvider('c1').future);
        expect(result, isFalse);
      });
    });

    group('isChoirMemberProvider', () {
      test('returns true if current user is member', () async {
        final mockRepository = MockChoirRepository();
        when(mockRepository.isMember('c1', 'user1'))
            .thenAnswer((_) async => true);

        final container = ProviderContainer(
          overrides: [
            choirRepositoryProvider.overrideWithValue(mockRepository),
          ],
        );

        final result = await container.read(isChoirMemberProvider('c1').future);
        expect(result, isTrue);
      });

      test('returns false if current user is not member', () async {
        final mockRepository = MockChoirRepository();
        when(mockRepository.isMember('c1', 'user1'))
            .thenAnswer((_) async => false);

        final container = ProviderContainer(
          overrides: [
            choirRepositoryProvider.overrideWithValue(mockRepository),
          ],
        );

        final result = await container.read(isChoirMemberProvider('c1').future);
        expect(result, isFalse);
      });
    });

    group('choirMemberCountProvider', () {
      test('returns the correct member count', () async {
        final mockRepository = MockChoirRepository();
        when(mockRepository.getMemberCount('c1'))
            .thenAnswer((_) async => 5);

        final container = ProviderContainer(
          overrides: [
            choirRepositoryProvider.overrideWithValue(mockRepository),
          ],
        );

        final result = await container.read(choirMemberCountProvider('c1').future);
        expect(result, 5);
      });
    });
  });
}
