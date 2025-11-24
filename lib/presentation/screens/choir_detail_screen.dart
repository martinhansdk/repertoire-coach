import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../providers/choir_provider.dart';
import '../providers/concert_provider.dart';
import '../widgets/concert_card.dart';

/// Choir Detail Screen
///
/// Shows choir information, concerts, and members.
/// Allows owner to manage members.
class ChoirDetailScreen extends ConsumerWidget {
  final String choirId;

  const ChoirDetailScreen({
    super.key,
    required this.choirId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final choirAsync = ref.watch(choirByIdProvider(choirId));
    final memberCountAsync = ref.watch(choirMemberCountProvider(choirId));
    final isOwnerAsync = ref.watch(isChoirOwnerProvider(choirId));
    final concertsAsync = ref.watch(concertsByChoirProvider(choirId));

    return Scaffold(
      appBar: AppBar(
        title: choirAsync.when(
          data: (choir) => Text(choir?.name ?? 'Choir'),
          loading: () => const Text('Loading...'),
          error: (_, __) => const Text('Error'),
        ),
      ),
      body: choirAsync.when(
        data: (choir) {
          if (choir == null) {
            return const Center(child: Text('Choir not found'));
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(choirByIdProvider(choirId));
              ref.invalidate(concertsByChoirProvider(choirId));
              ref.invalidate(choirMemberCountProvider(choirId));
            },
            child: ListView(
              padding: const EdgeInsets.all(AppConstants.paddingMedium),
              children: [
                // Choir info card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppConstants.paddingMedium),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.groups, size: 32),
                            const SizedBox(width: AppConstants.paddingSmall),
                            Expanded(
                              child: Text(
                                choir.name,
                                style: Theme.of(context).textTheme.headlineSmall,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppConstants.paddingSmall),
                        memberCountAsync.when(
                          data: (count) => Text('$count members'),
                          loading: () => const Text('Loading members...'),
                          error: (_, __) => const Text('Error loading members'),
                        ),
                        const SizedBox(height: AppConstants.paddingSmall),
                        isOwnerAsync.when(
                          data: (isOwner) => isOwner
                              ? const Chip(label: Text('You are the owner'))
                              : const SizedBox.shrink(),
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppConstants.paddingMedium),

                // Concerts section
                Text(
                  'Concerts',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppConstants.paddingSmall),
                concertsAsync.when(
                  data: (concerts) {
                    if (concerts.isEmpty) {
                      return const Card(
                        child: Padding(
                          padding: EdgeInsets.all(AppConstants.paddingMedium),
                          child: Text('No concerts yet'),
                        ),
                      );
                    }
                    return Column(
                      children: concerts
                          .map((concert) => ConcertCard(
                                concert: concert,
                                onTap: () {},
                              ))
                          .toList(),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (_, __) => const Text('Error loading concerts'),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, __) => Center(child: Text('Error: $error')),
      ),
    );
  }
}
