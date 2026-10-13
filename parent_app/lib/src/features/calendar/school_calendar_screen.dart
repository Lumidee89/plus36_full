import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';

final schoolCalendarProvider = FutureProvider.autoDispose<Map<String, dynamic>>(
  (ref) async {
    final cache = await SharedPreferences.getInstance();
    try {
      final response = await ref
          .watch(apiClientProvider)
          .get('/parent/calendar');
      final data = Map<String, dynamic>.from(response.data['data'] as Map);
      await cache.setString('parent_school_calendar', jsonEncode(data));
      return data;
    } catch (_) {
      final saved = cache.getString('parent_school_calendar');
      if (saved != null) {
        return Map<String, dynamic>.from(jsonDecode(saved) as Map);
      }
      rethrow;
    }
  },
);

class SchoolCalendarScreen extends ConsumerWidget {
  const SchoolCalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(schoolCalendarProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('School calendar')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(schoolCalendarProvider.future),
        child: state.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ListView(
            padding: const EdgeInsets.fromLTRB(24, 140, 24, 24),
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 46,
                color: AppColors.teal,
              ),
              const SizedBox(height: 14),
              Text(apiMessage(error), textAlign: TextAlign.center),
              TextButton(
                onPressed: () => ref.invalidate(schoolCalendarProvider),
                child: const Text('Try again'),
              ),
            ],
          ),
          data: (data) {
            final years = data['years'] as List? ?? [];
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: AppColors.forest,
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.calendar_month_rounded,
                        color: AppColors.mint,
                        size: 34,
                      ),
                      const SizedBox(height: 22),
                      Text(
                        data['school']?.toString() ?? 'Your school',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Academic years & terms',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 7),
                      const Text(
                        'Dates are published by your school administrator.',
                        style: TextStyle(color: Colors.white70, height: 1.4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                if (years.isEmpty)
                  const _EmptyCalendar()
                else
                  ...years.map(
                    (raw) => _AcademicYearCard(
                      year: Map<String, dynamic>.from(raw as Map),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AcademicYearCard extends StatelessWidget {
  const _AcademicYearCard({required this.year});
  final Map<String, dynamic> year;

  @override
  Widget build(BuildContext context) {
    final terms = year['terms'] as List? ?? [];
    final current = year['is_current'] == true;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: current ? AppColors.mint : AppColors.line,
          width: current ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  year['name']?.toString() ?? 'Academic year',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              if (current) const _CurrentBadge(label: 'Current year'),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            _range(year['starts_on'], year['ends_on']),
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 18),
          if (terms.isEmpty)
            const Text(
              'No terms have been published for this year.',
              style: TextStyle(color: AppColors.muted),
            )
          else
            ...terms.map(
              (raw) => _TermRow(term: Map<String, dynamic>.from(raw as Map)),
            ),
        ],
      ),
    );
  }
}

class _TermRow extends StatelessWidget {
  const _TermRow({required this.term});
  final Map<String, dynamic> term;

  @override
  Widget build(BuildContext context) {
    final current = term['is_current'] == true;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: current ? AppColors.softMint : AppColors.canvas,
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: current ? AppColors.mint : Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${term['sequence'] ?? ''}',
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
                Text(
                  term['name']?.toString() ?? 'Term',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  _range(term['starts_on'], term['ends_on']),
                  style: const TextStyle(color: AppColors.muted, fontSize: 11),
                ),
              ],
            ),
          ),
          if (current) const _CurrentBadge(label: 'Now'),
        ],
      ),
    );
  }
}

class _CurrentBadge extends StatelessWidget {
  const _CurrentBadge({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: AppColors.softMint,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: AppColors.teal,
        fontSize: 9,
        fontWeight: FontWeight.w900,
      ),
    ),
  );
}

class _EmptyCalendar extends StatelessWidget {
  const _EmptyCalendar();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(28),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
    ),
    child: const Column(
      children: [
        Icon(Icons.event_busy_outlined, size: 40, color: AppColors.teal),
        SizedBox(height: 12),
        Text(
          'No academic calendar yet',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
        ),
        SizedBox(height: 6),
        Text(
          'Your school administrator has not published academic years and terms.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted, height: 1.4),
        ),
      ],
    ),
  );
}

String _range(Object? start, Object? end) {
  final startDate = DateTime.tryParse(start?.toString() ?? '');
  final endDate = DateTime.tryParse(end?.toString() ?? '');
  if (startDate == null || endDate == null) return 'Dates not available';
  return '${DateFormat('MMM d, y').format(startDate)} – ${DateFormat('MMM d, y').format(endDate)}';
}
