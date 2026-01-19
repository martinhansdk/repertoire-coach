import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../core/services/sync_service.dart';
import '../providers/choir_provider.dart';
import '../providers/sync_provider.dart';
import '../widgets/choir_card.dart';
import '../widgets/create_choir_dialog.dart';
import 'choir_detail_screen.dart';

/// Choir List Screen
///
/// Displays all choirs where the current user is a member.
class ChoirListScreen extends ConsumerWidget {
  const ChoirListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final choirsAsync = ref.watch(choirsProvider);
    final syncState = ref.watch(syncControllerProvider);
    final isSyncing = syncState.status == SyncStatus.syncing;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Choirs'),
        actions: [
          if (isSyncing)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: choirsAsync.when(
        data: (choirs) {
          if (choirs.isEmpty) {
            return _EmptyState(
              onSync: () {
                ref.read(syncControllerProvider.notifier).syncFromRemote();
              },
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              // Trigger full sync from remote instead of just invalidating
              await ref.read(syncControllerProvider.notifier).syncFromRemote();
            },
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(
                vertical: AppConstants.paddingSmall,
              ),
              itemCount: choirs.length,
              itemBuilder: (context, index) {
                final choir = choirs[index];
                return ChoirCard(
                  choir: choir,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => ChoirDetailScreen(
                          choirId: choir.id,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stack) => _ErrorState(
          error: error.toString(),
          onRetry: () {
            ref.invalidate(choirsProvider);
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateChoirDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('New Choir'),
      ),
    );
  }

  Future<void> _showCreateChoirDialog(BuildContext context) async {
    await showDialog<String>(
      context: context,
      builder: (context) => const CreateChoirDialog(),
    );
  }
}

/// Empty state when no choirs are available
class _EmptyState extends StatelessWidget {
  final VoidCallback? onSync;

  const _EmptyState({this.onSync});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingLarge),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.groups_outlined,
              size: 80,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: AppConstants.paddingMedium),
            Text(
              'No Choirs Yet',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppConstants.paddingSmall),
            Text(
              'Create a new choir or sync from cloud',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (onSync != null) ...[
              const SizedBox(height: AppConstants.paddingMedium),
              OutlinedButton.icon(
                onPressed: onSync,
                icon: const Icon(Icons.sync),
                label: const Text('Sync from Cloud'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Error state with retry button
class _ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorState({
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingLarge),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: AppConstants.paddingMedium),
            Text(
              'Error Loading Choirs',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: AppConstants.paddingSmall),
            Text(
              error,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConstants.paddingMedium),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
