import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/local/local_choir_data_source.dart';
import '../../data/repositories/choir_repository_impl.dart';
import '../../domain/entities/choir.dart';
import '../../domain/repositories/choir_repository.dart';
import 'concert_provider.dart'; // For databaseProvider

/// Provider for the local choir data source
///
/// Wraps database operations for choir and membership management.
final localChoirDataSourceProvider = Provider<LocalChoirDataSource>((ref) {
  final database = ref.watch(databaseProvider);
  return LocalChoirDataSource(database);
});

/// Provider for the choir repository
///
/// This provides a single instance of the repository throughout the app.
/// Currently uses local Drift database. Future versions will add Supabase sync.
final choirRepositoryProvider = Provider<ChoirRepository>((ref) {
  final localDataSource = ref.watch(localChoirDataSourceProvider);
  return ChoirRepositoryImpl(localDataSource);
});

/// Provider for the current user ID
///
/// PHASE 1: Hardcoded to 'user1' for offline development and testing.
/// PHASE 2: Will be replaced with actual authenticated user from Supabase Auth.
final currentUserIdProvider = Provider<String>((ref) => 'user1');

/// Provider for the list of choirs for the current user
///
/// Returns all choirs where the current user is a member.
final choirsProvider = FutureProvider<List<Choir>>((ref) async {
  try {
    final userId = ref.watch(currentUserIdProvider);
    final repository = ref.watch(choirRepositoryProvider);
    return await repository.getChoirs(userId);
  } catch (e) {
    // On web, database might fail without sql.js setup
    // Return empty list (Phase 2 will use Supabase which works on all platforms)
    return [];
  }
});

/// Provider for a single choir by ID
///
/// Usage: ref.watch(choirByIdProvider('choir-id'))
final choirByIdProvider =
    FutureProvider.family<Choir?, String>((ref, choirId) async {
  final repository = ref.watch(choirRepositoryProvider);
  return await repository.getChoirById(choirId);
});

/// Provider for choir members (list of user IDs)
///
/// Usage: ref.watch(choirMembersProvider('choir-id'))
final choirMembersProvider =
    FutureProvider.family<List<String>, String>((ref, choirId) async {
  final repository = ref.watch(choirRepositoryProvider);
  return await repository.getMembers(choirId);
});

/// Provider to check if current user is owner of a choir
///
/// Usage: ref.watch(isChoirOwnerProvider('choir-id'))
final isChoirOwnerProvider =
    FutureProvider.family<bool, String>((ref, choirId) async {
  final userId = ref.watch(currentUserIdProvider);
  final repository = ref.watch(choirRepositoryProvider);
  return await repository.isOwner(choirId, userId);
});

/// Provider to check if current user is member of a choir
///
/// Usage: ref.watch(isChoirMemberProvider('choir-id'))
final isChoirMemberProvider =
    FutureProvider.family<bool, String>((ref, choirId) async {
  final userId = ref.watch(currentUserIdProvider);
  final repository = ref.watch(choirRepositoryProvider);
  return await repository.isMember(choirId, userId);
});

/// Provider for the member count of a choir
///
/// Usage: ref.watch(choirMemberCountProvider('choir-id'))
final choirMemberCountProvider =
    FutureProvider.family<int, String>((ref, choirId) async {
  final repository = ref.watch(choirRepositoryProvider);
  return await repository.getMemberCount(choirId);
});
