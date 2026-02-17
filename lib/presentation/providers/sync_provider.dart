import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/sync_service.dart';
import '../../data/datasources/remote/remote_marker_data_source.dart';
import 'auth_provider.dart';
import 'audio_player_provider.dart';
import 'choir_provider.dart';
import 'concert_provider.dart';
import 'favorite_track_provider.dart';
import 'marker_provider.dart';
import 'song_provider.dart';
import 'track_provider.dart';

/// Provider for the remote marker data source
///
/// Wraps Supabase operations for marker and marker set management.
/// Only available when user is authenticated.
final remoteMarkerDataSourceProvider =
    Provider<RemoteMarkerDataSource?>((ref) {
  final supabaseService = ref.watch(supabaseServiceProvider);
  if (!supabaseService.isAuthenticated) {
    return null;
  }
  return RemoteMarkerDataSource(supabaseService.client);
});

/// Provider for the sync service
///
/// Returns null if user is not authenticated (remote data sources unavailable).
final syncServiceProvider = Provider<SyncService?>((ref) {
  // Get all local data sources
  final localChoirDataSource = ref.watch(localChoirDataSourceProvider);
  final localConcertDataSource = ref.watch(localConcertDataSourceProvider);
  final localSongDataSource = ref.watch(localSongDataSourceProvider);
  final localTrackDataSource = ref.watch(localTrackDataSourceProvider);
  final localMarkerDataSource = ref.watch(localMarkerDataSourceProvider);
  final localFavoriteTrackDataSource =
      ref.watch(localFavoriteTrackDataSourceProvider);

  // Get all remote data sources (may be null if not authenticated)
  final remoteChoirDataSource = ref.watch(remoteChoirDataSourceProvider);
  final remoteConcertDataSource = ref.watch(remoteConcertDataSourceProvider);
  final remoteSongDataSource = ref.watch(remoteSongDataSourceProvider);
  final remoteTrackDataSource = ref.watch(remoteTrackDataSourceProvider);
  final remoteMarkerDataSource = ref.watch(remoteMarkerDataSourceProvider);
  final remoteFavoriteTrackDataSource =
      ref.watch(remoteFavoriteTrackDataSourceProvider);

  // Can't create sync service if any remote data source is null
  if (remoteChoirDataSource == null ||
      remoteConcertDataSource == null ||
      remoteSongDataSource == null ||
      remoteTrackDataSource == null ||
      remoteMarkerDataSource == null ||
      remoteFavoriteTrackDataSource == null) {
    return null;
  }

  return SyncService(
    localChoirDataSource: localChoirDataSource,
    localConcertDataSource: localConcertDataSource,
    localSongDataSource: localSongDataSource,
    localTrackDataSource: localTrackDataSource,
    localMarkerDataSource: localMarkerDataSource,
    localFavoriteTrackDataSource: localFavoriteTrackDataSource,
    remoteChoirDataSource: remoteChoirDataSource,
    remoteConcertDataSource: remoteConcertDataSource,
    remoteSongDataSource: remoteSongDataSource,
    remoteTrackDataSource: remoteTrackDataSource,
    remoteMarkerDataSource: remoteMarkerDataSource,
    remoteFavoriteTrackDataSource: remoteFavoriteTrackDataSource,
  );
});

/// Controller for sync operations
///
/// Manages sync state and triggers sync operations.
/// After sync completes, invalidates relevant providers to refresh data.
class SyncController extends Notifier<SyncState> {
  @override
  SyncState build() => SyncState.initial;

  /// Whether sync is available (user is authenticated)
  bool get canSync {
    final syncService = ref.read(syncServiceProvider);
    final userId = ref.read(supabaseServiceProvider).currentUserId;
    return syncService != null && userId != null;
  }

  /// Sync data from remote Supabase to local database
  ///
  /// Pulls all data accessible to the current user and upserts
  /// it into the local database. After sync, invalidates providers
  /// to refresh UI with new data.
  Future<void> syncFromRemote() async {
    final syncService = ref.read(syncServiceProvider);
    final userId = ref.read(supabaseServiceProvider).currentUserId;

    if (syncService == null || userId == null) {
      state = SyncState.error('Not authenticated');
      return;
    }

    try {
      await syncService.syncFromRemote(
        userId,
        onProgress: (syncState) {
          state = syncState;
        },
      );

      // Invalidate providers to refresh data after successful sync
      _refreshProviders();
    } catch (e) {
      state = SyncState.error('Sync failed: $e');
    }
  }

  /// Refresh all data providers after sync
  void _refreshProviders() {
    ref.invalidate(choirsProvider);
    ref.invalidate(choirMemberCountProvider);
    ref.invalidate(choirMembersProvider);
    ref.invalidate(concertsProvider);
    ref.invalidate(markerSetsByTrackProvider);
    ref.invalidate(markerSetByIdProvider);
    ref.invalidate(markersByMarkerSetProvider);
    ref.invalidate(favoritesProvider);
    ref.invalidate(favoriteCountProvider);
    // Note: songsByConcertProvider and tracksBySongProvider are family
    // providers and will be refreshed when their parents are refreshed
  }

  /// Reset sync state to idle
  void resetState() {
    state = SyncState.initial;
  }
}

/// Notifier provider for sync state and operations
///
/// Manages sync state and provides methods to trigger sync operations.
final syncControllerProvider =
    NotifierProvider<SyncController, SyncState>(SyncController.new);

/// Provider to check if sync is in progress
final isSyncingProvider = Provider<bool>((ref) {
  final syncState = ref.watch(syncControllerProvider);
  return syncState.status == SyncStatus.syncing;
});

/// Provider to check if last sync had an error
final syncErrorProvider = Provider<String?>((ref) {
  final syncState = ref.watch(syncControllerProvider);
  if (syncState.status == SyncStatus.error) {
    return syncState.message;
  }
  return null;
});

/// Provider that triggers sync when user signs in
///
/// This provider watches the currentUserProvider and automatically
/// triggers a sync when a user becomes authenticated.
/// Include this provider in your app's widget tree to enable auto-sync.
///
/// Example usage in your app:
/// ```dart
/// class MyApp extends ConsumerWidget {
///   @override
///   Widget build(BuildContext context, WidgetRef ref) {
///     // Enable auto-sync on sign-in
///     ref.watch(authSyncTriggerProvider);
///     return MaterialApp(...);
///   }
/// }
/// ```
final authSyncTriggerProvider = Provider<void>((ref) {
  // Watch the current user
  final userAsync = ref.watch(currentUserProvider);

  // When user becomes non-null (signed in), trigger sync
  userAsync.whenData((user) {
    if (user != null) {
      // Only trigger sync if we haven't already synced or had an error
      final currentState = ref.read(syncControllerProvider);
      if (currentState.status == SyncStatus.idle) {
        // Trigger sync asynchronously to not block provider initialization
        Future.microtask(() {
          ref.read(syncControllerProvider.notifier).syncFromRemote();
        });
      }
    }
  });
});
