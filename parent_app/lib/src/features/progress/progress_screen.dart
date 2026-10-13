import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/json_cache.dart';
import '../../core/theme.dart';
import '../home/home_screen.dart';
import '../children/selected_child.dart';

final progressProvider = FutureProvider.autoDispose<Map<String, dynamic>>((
  ref,
) async {
  final dashboard = await ref.watch(dashboardProvider.future);
  final children = dashboard['children'] as List;
  if (children.isEmpty) return {'subjects': [], 'average': 0};
  final active = selectedChild(children, ref.watch(selectedChildIdProvider));
  final id = active['id'];
  return JsonCache.through<Map<String, dynamic>>(
    'parent_progress_$id',
    () async {
      final api = ref.watch(apiClientProvider);
      final responses = await Future.wait([
        api.get('/parent/children/$id/progress'),
        api.get('/parent/children/$id/recommendations'),
      ]);
      final progress = Map<String, dynamic>.from(
        responses[0].data['data'] as Map,
      );
      final insight = Map<String, dynamic>.from(
        responses[1].data['data'] as Map,
      );
      return {
        ...progress,
        'success_score': insight['success_score'],
        'risk_level': insight['risk_level'],
        'recommendations': insight['recommendations'],
      };
    },
  );
});

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardProvider).valueOrNull;
    final children = dashboard?['children'] as List? ?? [];
    return RefreshIndicator.adaptive(
      triggerMode: RefreshIndicatorTriggerMode.anywhere,
      displacement: 48,
      onRefresh: () async {
        ref.invalidate(dashboardProvider);
        ref.invalidate(progressProvider);
        await ref.read(progressProvider.future);
      },
      child: ref
          .watch(progressProvider)
          .when(
            loading: () => ListView(
              physics: AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(height: 240),
                Center(child: CircularProgressIndicator()),
              ],
            ),
            error: (e, _) => ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 220),
                Center(child: Text(apiMessage(e))),
              ],
            ),
            data: (data) => ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
              const SizedBox(height: 8),
              Text(
                'Progress',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const Text(
                'Track learning outcomes and helpful next steps.',
                style: TextStyle(color: AppColors.muted),
              ),
              if (children.length > 1) ...[
                const SizedBox(height: 16),
                ChildSwitcher(children: children),
              ],
              const SizedBox(height: 16),
              Container(
                height: 150,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: AppColors.forest,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x3306322C),
                      blurRadius: 22,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'CURRENT AVERAGE',
                            style: TextStyle(
                              color: AppColors.mint,
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            '${data['average']}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 38,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            data['risk_level'] == null
                                ? 'Academic performance'
                                : '${data['risk_level']} risk level',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 78,
                      height: 78,
                      child: CircularProgressIndicator(
                        value: ((num.tryParse('${data['average']}') ?? 0) / 100)
                            .clamp(0, 1),
                        strokeWidth: 9,
                        color: AppColors.mint,
                        backgroundColor: Colors.white24,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Learning recommendations',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          if (data['success_score'] != null)
                            Chip(label: Text('${data['success_score']} / 100')),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...(data['recommendations'] as List? ?? []).map(
                        (recommendation) => Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 3),
                                child: Icon(Icons.auto_awesome, size: 16),
                              ),
                              const SizedBox(width: 8),
                              Expanded(child: Text(recommendation.toString())),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'CBT examinations',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              const Text(
                'Submitted online exams and their grading status.',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              const SizedBox(height: 12),
              if ((data['cbt_attempts'] as List? ?? []).isEmpty)
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'No submitted CBT examinations yet.',
                    style: TextStyle(color: AppColors.muted),
                  ),
                ),
              ...(data['cbt_attempts'] as List? ?? []).map((item) {
                final graded = item['status'] == 'graded';
                final passed = item['passed'] == true;
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: graded
                              ? (passed
                                    ? AppColors.softMint
                                    : const Color(0xFFFFECE7))
                              : const Color(0xFFFFF5D9),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          graded
                              ? Icons.assignment_turned_in_rounded
                              : Icons.hourglass_top_rounded,
                          color: graded
                              ? (passed ? AppColors.teal : AppColors.orange)
                              : const Color(0xFFB7791F),
                        ),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['exam']?.toString() ?? 'CBT exam',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${item['subject'] ?? 'Subject'} • ${item['term'] ?? 'Term'}',
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 12,
                              ),
                            ),
                            if (!graded)
                              const Text(
                                'Waiting for teacher review',
                                style: TextStyle(
                                  color: Color(0xFFB7791F),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (graded)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${item['percentage'] ?? 0}%',
                              style: const TextStyle(
                                color: AppColors.forest,
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              '${item['score'] ?? 0}/${item['maximum_score'] ?? 0}',
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 24),
              Text('Subjects', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              ...(data['subjects'] as List? ?? []).map(
                (item) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    leading: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.softMint,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(
                        Icons.menu_book_rounded,
                        color: AppColors.teal,
                      ),
                    ),
                    title: Text(
                      item['subject'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text('${item['assessment']} • ${item['term']}'),
                    trailing: Text(
                      '${item['percentage']}%\n${item['grade']}',
                      textAlign: TextAlign.right,
                    ),
                  ),
                ),
              ),
              ],
            ),
          ),
    );
  }
}
