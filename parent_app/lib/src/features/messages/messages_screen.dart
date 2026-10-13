import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/json_cache.dart';
import '../../core/offline_store.dart';
import '../../core/theme.dart';
import '../../core/widgets/success_bottom_sheet.dart';

final conversationsProvider = FutureProvider.autoDispose<List>(
  (ref) => JsonCache.through<List>(
    'parent_conversations',
    () async =>
        (await ref.watch(apiClientProvider).get('/parent/conversations'))
                .data['data']
            as List,
  ),
);
final messageContactsProvider = FutureProvider.autoDispose<List>(
  (ref) async =>
      (await ref.watch(apiClientProvider).get('/parent/message-contacts'))
              .data['data']
          as List,
);
final threadProvider = FutureProvider.autoDispose.family<List, int>(
  (ref, id) => JsonCache.through<List>(
    'parent_conversation_$id',
    () async =>
        (await ref.watch(apiClientProvider).get('/parent/conversations/$id'))
            .data['data'] as List,
  ),
);

class MessagesScreen extends ConsumerWidget {
  const MessagesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    floatingActionButton: FloatingActionButton(
      backgroundColor: AppColors.forest,
      foregroundColor: Colors.white,
      onPressed: () => _compose(context, ref),
      child: const Icon(Icons.edit_outlined),
    ),
    body: ref
        .watch(conversationsProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text(apiMessage(error))),
          data: (items) => RefreshIndicator(
            onRefresh: () => ref.refresh(conversationsProvider.future),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const SizedBox(height: 8),
                Text(
                  'Messages',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const Text(
                  'Send questions directly to your school administration.',
                  style: TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 18),
                if (items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 100),
                    child: Center(child: Text('No conversations yet.')),
                  ),
                ...items.map(
                  (item) => Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      leading: const CircleAvatar(
                        backgroundColor: AppColors.softMint,
                        child: Icon(
                          Icons.person_outline,
                          color: AppColors.forest,
                        ),
                      ),
                      title: Text(
                        item['subject'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        item['last_message'] ?? 'No messages',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ConversationScreen(
                            id: item['id'],
                            subject: item['subject'],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
  );

  Future<void> _compose(BuildContext context, WidgetRef ref) async {
    List contacts;
    try {
      contacts = await ref.read(messageContactsProvider.future);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiMessage(error))));
      }
      return;
    }
    if (!context.mounted) return;
    if (contacts.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No school contacts are available.')),
        );
      }
      return;
    }
    final subject = TextEditingController();
    final body = TextEditingController();
    int selectedRecipientId = contacts.first['id'] as int;
    var busy = false;
    String? error;
    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setState) => AlertDialog(
          title: const Text('New message'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: selectedRecipientId,
                  decoration: const InputDecoration(
                    labelText: 'Send to',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  items: contacts
                      .map<DropdownMenuItem<int>>(
                        (contact) => DropdownMenuItem(
                          value: contact['id'] as int,
                          child: Text(
                            '${contact['name']} — ${contact['role_label'] ?? contact['role']}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: busy
                      ? null
                      : (value) => setState(
                          () => selectedRecipientId = value ?? selectedRecipientId,
                        ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: subject,
                  maxLength: 150,
                  decoration: const InputDecoration(
                    labelText: 'Subject',
                    hintText: 'What do you need help with?',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: body,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Message'),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      if (subject.text.trim().isEmpty ||
                          body.text.trim().isEmpty) {
                        setState(
                          () => error = 'Enter both a subject and message.',
                        );
                        return;
                      }
                      setState(() {
                        busy = true;
                        error = null;
                      });
                      try {
                        await ref
                            .read(apiClientProvider)
                            .post(
                              '/parent/conversations',
                              data: {
                                'recipient_id': selectedRecipientId,
                                'subject': subject.text.trim(),
                                'body': body.text.trim(),
                              },
                            );
                        ref.invalidate(conversationsProvider);
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                          await showSuccessBottomSheet(
                            context,
                            title: 'Message sent',
                            message: 'Your selected school contact has received your message.',
                          );
                        }
                      } catch (exception) {
                        if (isNetworkError(exception)) {
                          await OfflineStore.enqueue(
                            'POST',
                            '/parent/conversations',
                            data: {
                              'recipient_id': selectedRecipientId,
                              'subject': subject.text.trim(),
                              'body': body.text.trim(),
                            },
                          );
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                            await showSuccessBottomSheet(
                              context,
                              title: 'Message saved',
                              message: 'It will be sent automatically when you are online.',
                            );
                          }
                        } else {
                          setState(() => error = apiMessage(exception));
                        }
                      } finally {
                        if (dialogContext.mounted) {
                          setState(() => busy = false);
                        }
                      }
                    },
              child: Text(busy ? 'Sending…' : 'Send'),
            ),
          ],
        ),
      ),
    );
  }
}

class ConversationScreen extends ConsumerStatefulWidget {
  const ConversationScreen({
    super.key,
    required this.id,
    required this.subject,
  });
  final int id;
  final String subject;
  @override
  ConsumerState<ConversationScreen> createState() => _ConversationState();
}

class _ConversationState extends ConsumerState<ConversationScreen> {
  final reply = TextEditingController();
  bool sending = false;
  Future<void> send() async {
    if (reply.text.trim().isEmpty) return;
    setState(() => sending = true);
    final text = reply.text.trim();
    try {
      await ref
          .read(apiClientProvider)
          .post(
            '/parent/conversations/${widget.id}/messages',
            data: {'body': text},
          );
      reply.clear();
      ref.invalidate(threadProvider(widget.id));
      ref.invalidate(conversationsProvider);
    } catch (error) {
      if (!isNetworkError(error)) rethrow;
      await OfflineStore.enqueue(
        'POST',
        '/parent/conversations/${widget.id}/messages',
        data: {'body': text},
      );
      reply.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reply saved and will send when online.')),
        );
      }
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.subject)),
    body: Column(
      children: [
        Expanded(
          child: ref
              .watch(threadProvider(widget.id))
              .when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text(apiMessage(e))),
                data: (items) => ListView(
                  padding: const EdgeInsets.all(16),
                  children: items
                      .map(
                        (item) => Align(
                          alignment: item['sender']['role'] == 'parent'
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            constraints: const BoxConstraints(maxWidth: 300),
                            decoration: BoxDecoration(
                              color: item['sender']['role'] == 'parent'
                                  ? Theme.of(context)
                                        .colorScheme
                                        .secondaryContainer
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['sender']['name'],
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(item['body']),
                              ],
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: reply,
                    decoration: const InputDecoration(
                      hintText: 'Write a reply…',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: sending ? null : send,
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
