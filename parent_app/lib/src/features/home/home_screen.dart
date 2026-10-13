import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../notifications/notifications_screen.dart';
import '../children/selected_child.dart';

final dashboardProvider = FutureProvider.autoDispose<Map<String, dynamic>>((
  ref,
) async {
  final cache = await SharedPreferences.getInstance();
  try {
    final response = await ref
        .watch(apiClientProvider)
        .get('/parent/dashboard');
    final data = Map<String, dynamic>.from(response.data['data']);
    await cache.setString('parent_dashboard', jsonEncode(data));
    return data;
  } catch (_) {
    final saved = cache.getString('parent_dashboard');
    if (saved != null) return Map<String, dynamic>.from(jsonDecode(saved));
    rethrow;
  }
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardProvider);
    return RefreshIndicator(
      onRefresh: () => ref.refresh(dashboardProvider.future),
      child: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ListView(
          children: [
            const SizedBox(height: 180),
            const Icon(
              Icons.cloud_off_rounded,
              size: 44,
              color: AppColors.teal,
            ),
            const SizedBox(height: 12),
            Center(child: Text(apiMessage(error))),
            Center(
              child: TextButton(
                onPressed: () => ref.invalidate(dashboardProvider),
                child: const Text('Try again'),
              ),
            ),
          ],
        ),
        data: (data) {
          final children = data['children'] as List? ?? [];
          final selectedId = ref.watch(selectedChildIdProvider);
          final announcements = data['announcements'] as List? ?? [];
          final events = data['upcoming_events'] as List? ?? [];
          final allHomework = data['homework'] as List? ?? [];
          final first = selectedChild(children, selectedId);
          final homework = allHomework
              .where((item) => '${item['class_id']}' == '${first['class_id']}')
              .toList();
          final name =
              (first['parent_name'] ?? data['parent']?['name'] ?? 'Parent')
                  .toString()
                  .split(' ')
                  .first;
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              _Header(name: name),
              const SizedBox(height: 28),
              Text(
                'Good ${_dayPart()},',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const Text(
                'Here is how your family is doing today.',
                style: TextStyle(color: AppColors.muted),
              ),
              if (children.length > 1) ...[
                const SizedBox(height: 18),
                ChildSwitcher(children: children),
              ],
              const SizedBox(height: 24),
              const _DateStrip(),
              const SizedBox(height: 28),
              _SectionTitle(
                title: 'Overview',
                action:
                    '${children.length} ${children.length == 1 ? 'child' : 'children'}',
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 166,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _OverviewCard(
                      label: 'Attendance',
                      value: '${first['today_attendance'] ?? '—'}',
                      icon: Icons.fact_check_rounded,
                      color: AppColors.forest,
                    ),
                    _OverviewCard(
                      label: 'Average score',
                      value: '${first['current_average'] ?? 0}%',
                      icon: Icons.auto_graph_rounded,
                      color: AppColors.teal,
                    ),
                    _OverviewCard(
                      label: 'Outstanding',
                      value: _compactMoney(first['outstanding_fees']),
                      icon: Icons.account_balance_wallet_rounded,
                      color: AppColors.orange,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              const _SectionTitle(
                title: 'My children',
                action: 'School profile',
              ),
              const SizedBox(height: 14),
              if (children.isEmpty)
                const _EmptyCard(
                  text: 'No student has been linked to your account yet.',
                ),
              ...children.map((raw) {
                final child = Map<String, dynamic>.from(raw as Map);
                return _ChildCard(
                  child: child,
                  selected: child['id'].toString() == first['id'].toString(),
                  onTap: () =>
                      ref.read(selectedChildIdProvider.notifier).state =
                          int.parse(child['id'].toString()),
                );
              }),
              const SizedBox(height: 22),
              _SectionTitle(
                title: 'Homework',
                action: homework.isEmpty ? '' : '${homework.length} upcoming',
              ),
              const SizedBox(height: 14),
              if (homework.isEmpty)
                const _EmptyCard(text: 'No published homework is due.'),
              ...homework.map(
                (raw) => _PlanningCard(
                  icon: Icons.assignment_rounded,
                  title: '${raw['title']}',
                  subtitle:
                      '${raw['subject'] ?? 'Subject'} · Due ${_formatDate(raw['due_at'])}',
                  body: '${raw['instructions'] ?? ''}',
                ),
              ),
              const SizedBox(height: 22),
              _SectionTitle(
                title: 'Upcoming events',
                action: events.isEmpty ? '' : '${events.length} scheduled',
              ),
              const SizedBox(height: 14),
              if (events.isEmpty)
                const _EmptyCard(text: 'No upcoming parent events.'),
              ...events.map(
                (raw) => _PlanningCard(
                  icon: Icons.event_rounded,
                  title: '${raw['title']}',
                  subtitle:
                      '${_formatDate(raw['starts_at'])} · ${raw['location'] ?? 'School event'}',
                  body: '${raw['description'] ?? ''}',
                ),
              ),
              const SizedBox(height: 22),
              _SectionTitle(
                title: 'School updates',
                action: announcements.isEmpty ? '' : 'Latest',
              ),
              const SizedBox(height: 14),
              if (announcements.isEmpty)
                const _EmptyCard(
                  text: 'There are no school announcements yet.',
                ),
              ...announcements.map(
                (raw) =>
                    _Announcement(item: Map<String, dynamic>.from(raw as Map)),
              ),
            ],
          );
        },
      ),
    );
  }

  static String _dayPart() {
    final hour = DateTime.now().hour;
    return hour < 12
        ? 'morning'
        : hour < 17
        ? 'afternoon'
        : 'evening';
  }

  static String _compactMoney(Object? value) {
    final amount = num.tryParse('${value ?? 0}') ?? 0;
    return NumberFormat.compactCurrency(
      symbol: '₦',
      decimalDigits: 0,
    ).format(amount);
  }

  static String _formatDate(Object? value) {
    final date = DateTime.tryParse('${value ?? ''}');
    return date == null
        ? 'Date pending'
        : DateFormat('EEE, MMM d · h:mm a').format(date.toLocal());
  }
}

class _PlanningCard extends StatelessWidget {
  const _PlanningCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.body,
  });
  final IconData icon;
  final String title, subtitle, body;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: AppColors.mint.withValues(alpha: .22),
            child: Icon(icon, color: AppColors.forest),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(color: AppColors.teal, fontSize: 12),
                ),
                if (body.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(body, maxLines: 3, overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _Header extends StatelessWidget {
  const _Header({required this.name});
  final String name;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
        ),
        child: const Icon(Icons.grid_view_rounded, color: AppColors.forest),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Image.asset(
          'logo.png',
          height: 38,
          alignment: Alignment.centerLeft,
          errorBuilder: (_, _, _) => const Text(
            'Plus36 SchoolOS',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ),
      IconButton.filledTonal(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NotificationsScreen()),
        ),
        icon: const Icon(Icons.notifications_none_rounded),
        tooltip: 'Notifications',
      ),
      const SizedBox(width: 6),
      CircleAvatar(
        backgroundColor: AppColors.forest,
        child: Text(
          name.isEmpty ? 'P' : name[0].toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    ],
  );
}

class _DateStrip extends StatelessWidget {
  const _DateStrip();
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(5, (index) {
        final date = now.add(Duration(days: index - 2));
        final selected = index == 2;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 57,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.forest : Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: Color(0x3306322C),
                      blurRadius: 16,
                      offset: Offset(0, 7),
                    ),
                  ]
                : null,
          ),
          child: Column(
            children: [
              Text(
                '${date.day}',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                  color: selected ? Colors.white : AppColors.ink,
                ),
              ),
              Text(
                DateFormat.E().format(date),
                style: TextStyle(
                  fontSize: 11,
                  color: selected ? AppColors.mint : AppColors.muted,
                ),
              ),
              if (selected)
                const Padding(
                  padding: EdgeInsets.only(top: 5),
                  child: Icon(
                    Icons.notifications_none_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.action});
  final String title, action;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.titleLarge),
      ),
      if (action.isNotEmpty)
        Text(
          action,
          style: const TextStyle(
            color: AppColors.teal,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
    ],
  );
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String label, value;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    width: 146,
    margin: const EdgeInsets.only(right: 12),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(26),
      boxShadow: [
        BoxShadow(
          color: color.withValues(alpha: .22),
          blurRadius: 22,
          offset: const Offset(0, 10),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: Colors.white, size: 23),
            const Icon(Icons.more_horiz, color: Colors.white70),
          ],
        ),
        const Spacer(),
        Text(
          value,
          maxLines: 1,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 25,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ],
    ),
  );
}

class _ChildCard extends StatelessWidget {
  const _ChildCard({
    required this.child,
    required this.selected,
    required this.onTap,
  });
  final Map<String, dynamic> child;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(22),
    child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: selected ? AppColors.softMint : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: selected ? AppColors.mint : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: AppColors.softMint,
            child: Text(
              (child['name']?.toString() ?? 'S')[0].toUpperCase(),
              style: const TextStyle(
                color: AppColors.forest,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  child['name']?.toString() ?? 'Student',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                Text(
                  child['class']?.toString() ?? 'Class not assigned',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: AppColors.canvas,
              shape: BoxShape.circle,
            ),
            child: Icon(
              selected ? Icons.check_rounded : Icons.chevron_right_rounded,
              color: AppColors.teal,
            ),
          ),
        ],
      ),
    ),
  );
}

class _Announcement extends StatelessWidget {
  const _Announcement({required this.item});
  final Map<String, dynamic> item;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.softMint,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.campaign_rounded, color: AppColors.teal),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item['title']?.toString() ?? 'School update',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                item['body']?.toString() ?? '',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.muted, height: 1.35),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
    ),
    child: Text(text, style: const TextStyle(color: AppColors.muted)),
  );
}
