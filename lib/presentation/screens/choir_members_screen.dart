import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../providers/choir_provider.dart';
import '../widgets/add_member_dialog.dart';

/// Choir Members Screen
///
/// Shows list of members. Owner can add/remove members.
class ChoirMembersScreen extends ConsumerWidget {
  final String choirId;

  const ChoirMembersScreen({
    super.key,
    required this.choirId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final choirAsync = ref.watch(choirByIdProvider(choirId));
    final membersAsync = ref.watch(choirMembersProvider(choirId));
    final isOwnerAsync = ref.watch(isChoirOwnerProvider(choirId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Members'),
      ),
      body: membersAsync.when(
        data: (members) {
          if (members.isEmpty) {
            return const Center(child: Text('No members'));
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(choirMembersProvider(choirId));
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(AppConstants.paddingSmall),
              itemCount: members.length,
              itemBuilder: (context, index) {
                final userId = members[index];
                final isOwner = choirAsync.value?.ownerId == userId;

                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(userId[0].toUpperCase()),
                    ),
                    title: Text(userId),
                    subtitle: isOwner ? const Text('Owner') : null,
                    trailing: isOwnerAsync.when(
                      data: (currentUserIsOwner) =>
                          currentUserIsOwner && !isOwner
                              ? IconButton(
                                  icon: const Icon(Icons.remove_circle_outline),
                                  onPressed: () =>
                                      _removeMember(context, ref, userId),
                                )
                              : null,
                      loading: () => null,
                      error: (_, __) => null,
                    ),
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
      floatingActionButton: isOwnerAsync.when(
        data: (isOwner) => isOwner
            ? FloatingActionButton.extended(
                onPressed: () => _showAddMemberDialog(context),
                icon: const Icon(Icons.person_add),
                label: const Text('Add Member'),
              )
            : null,
        loading: () => null,
        error: (_, __) => null,
      ),
    );
  }

  Future<void> _showAddMemberDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) => AddMemberDialog(choirId: choirId),
    );
  }

  Future<void> _removeMember(
    BuildContext context,
    WidgetRef ref,
    String userId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Member'),
        content: Text('Remove $userId from this choir?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final repository = ref.read(choirRepositoryProvider);
      await repository.removeMember(choirId, userId);

      if (context.mounted) {
        ref.invalidate(choirMembersProvider(choirId));
        ref.invalidate(choirMemberCountProvider(choirId));

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Member removed'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
