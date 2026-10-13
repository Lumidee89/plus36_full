import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/json_cache.dart';
import '../../core/offline_store.dart';

final notificationsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((
  ref,
) {
  return JsonCache.through<Map<String, dynamic>>(
    'parent_notifications',
    () async {
      final response = await ref
          .watch(apiClientProvider)
          .get('/parent/notifications');
      return Map<String, dynamic>.from(response.data as Map);
    },
  );
});

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  Future<void> _markRead(WidgetRef ref, String id) async {
    try {
      await ref.read(apiClientProvider).patch('/parent/notifications/$id/read');
    } catch (error) {
      if (!isNetworkError(error)) rethrow;
      await OfflineStore.enqueue('PATCH', '/parent/notifications/$id/read');
    }
    ref.invalidate(notificationsProvider);
  }

  Future<void> _markAllRead(WidgetRef ref) async {
    try {
      await ref.read(apiClientProvider).patch('/parent/notifications/read-all');
    } catch (error) {
      if (!isNetworkError(error)) rethrow;
      await OfflineStore.enqueue('PATCH', '/parent/notifications/read-all');
    }
    ref.invalidate(notificationsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: state.valueOrNull?['unread_count'] == 0
                ? null
                : () => _markAllRead(ref),
            child: const Text('Read all'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(notificationsProvider.future),
        child: state.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              const SizedBox(height: 180),
              Center(child: Text(apiMessage(error))),
            ],
          ),
          data: (payload) {
            final items = payload['data'] as List? ?? [];
            if (items.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 180),
                  Icon(Icons.notifications_none, size: 48),
                  SizedBox(height: 12),
                  Center(child: Text('No notifications yet.')),
                ],
              );
            }
            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = Map<String, dynamic>.from(items[index] as Map);
                final unread = item['read_at'] == null;
                return Card(
                  elevation: 0,
                  child: ListTile(
                    onTap: unread
                        ? () => _markRead(ref, item['id'].toString())
                        : null,
                    leading: CircleAvatar(
                      child: Icon(_iconFor(item['kind']?.toString())),
                    ),
                    title: Text(
                      item['title']?.toString() ?? 'SchoolOS update',
                      style: TextStyle(
                        fontWeight: unread ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text(item['body']?.toString() ?? ''),
                    ),
                    trailing: unread
                        ? Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                          )
                        : null,
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  IconData _iconFor(String? kind) => switch (kind) {
    'payment' => Icons.receipt_long_outlined,
    'result' => Icons.school_outlined,
    'attendance' => Icons.fact_check_outlined,
    _ => Icons.campaign_outlined,
  };
}
