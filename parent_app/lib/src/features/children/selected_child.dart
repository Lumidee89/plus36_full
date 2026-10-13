import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';

final selectedChildIdProvider = StateProvider<int?>((ref) => null);

Map<String, dynamic> selectedChild(List<dynamic> children, int? selectedId) {
  if (children.isEmpty) return <String, dynamic>{};
  final match = children.where(
    (raw) => (raw as Map)['id'].toString() == selectedId?.toString(),
  );
  return Map<String, dynamic>.from(
    (match.isNotEmpty ? match.first : children.first) as Map,
  );
}

class ChildSwitcher extends ConsumerWidget {
  const ChildSwitcher({super.key, required this.children});
  final List<dynamic> children;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (children.length < 2) return const SizedBox.shrink();
    final selectedId = ref.watch(selectedChildIdProvider);
    final active = selectedChild(children, selectedId);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.softMint,
            child: Text(
              (active['name']?.toString() ?? 'S')[0].toUpperCase(),
              style: const TextStyle(
                color: AppColors.forest,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Viewing child',
                  style: TextStyle(color: AppColors.muted, fontSize: 10),
                ),
                Text(
                  active['name']?.toString() ?? 'Student',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          PopupMenuButton<int>(
            tooltip: 'Switch child',
            icon: const Icon(Icons.swap_horiz_rounded, color: AppColors.teal),
            onSelected: (id) =>
                ref.read(selectedChildIdProvider.notifier).state = id,
            itemBuilder: (_) => children.map((raw) {
              final child = Map<String, dynamic>.from(raw as Map);
              final id = int.parse(child['id'].toString());
              return PopupMenuItem<int>(
                value: id,
                child: Row(
                  children: [
                    Icon(
                      id.toString() == active['id'].toString()
                          ? Icons.check_circle_rounded
                          : Icons.circle_outlined,
                      color: AppColors.teal,
                      size: 19,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            child['name']?.toString() ?? 'Student',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            child['class']?.toString() ?? 'Class not assigned',
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
