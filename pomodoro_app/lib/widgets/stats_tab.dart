import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/session.dart';
import '../services/session_manager.dart';
import '../services/subject_manager.dart';
import 'sticky_note.dart';

enum _Range { day, week, month }

String formatDuration(int minutes) {
  if (minutes < 60) return '${minutes}m';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m > 0 ? '${h}h ${m}m' : '${h}h';
}

class StatsTab extends StatefulWidget {
  const StatsTab({super.key});

  @override
  State<StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<StatsTab> {
  _Range _range = _Range.day;

  DateTime get _startDate {
    final now = DateTime.now();
    switch (_range) {
      case _Range.day:
        return DateTime(now.year, now.month, now.day);
      case _Range.week:
        return now.subtract(const Duration(days: 7));
      case _Range.month:
        return DateTime(now.year, now.month - 1, now.day);
    }
  }

  String _dayLabel(DateTime d) {
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return labels[d.weekday - 1];
  }

  String _shortDate(DateTime d) {
    return '${d.month}/${d.day}';
  }

  @override
  Widget build(BuildContext context) {
    final sessions = context.watch<SessionManager>().sessions;
    final subjectManager = context.watch<SubjectManager>();

    final start = _startDate;
    final filtered =
        sessions.where((s) => s.completedAt.isAfter(start)).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            _buildOverview(filtered),
            const SizedBox(height: 24),
            _buildSubjectBreakdown(filtered, subjectManager),
            const SizedBox(height: 24),
            if (_range == _Range.week || _range == _Range.month)
              _buildDailyChart(filtered)
            else
              _buildSessionList(filtered, subjectManager),
          ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const Text(
          'Stats',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Color(0xFF3A2E27),
          ),
        ),
        const Spacer(),
        SegmentedButton<_Range>(
          segments: const [
            ButtonSegment(value: _Range.day, label: Text('Day')),
            ButtonSegment(value: _Range.week, label: Text('Week')),
            ButtonSegment(value: _Range.month, label: Text('Month')),
          ],
          selected: {_range},
          onSelectionChanged: (set) => setState(() => _range = set.first),
          style: SegmentedButton.styleFrom(
            selectedBackgroundColor:
                const Color(0xFF8B5A2B).withOpacity(0.12),
            selectedForegroundColor: const Color(0xFF8B5A2B),
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF3A2E27).withOpacity(0.5),
            elevation: 0,
            side: BorderSide.none,
            textStyle:
                const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            visualDensity: VisualDensity.compact,
          ),
        ),
      ],
    );
  }

  Widget _buildOverview(List<PomodoroSession> filtered) {
    final totalSessions = filtered.length;
    final totalMinutes =
        filtered.fold<int>(0, (s, v) => s + v.durationMinutes);

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            value: '$totalSessions',
            label: totalSessions == 1 ? 'session' : 'sessions',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            value: formatDuration(totalMinutes),
            label: 'focus time',
          ),
        ),
      ],
    );
  }

  Widget _buildSubjectBreakdown(
      List<PomodoroSession> filtered, SubjectManager sm) {
    final groups = <String?, List<PomodoroSession>>{};
    for (final s in filtered) {
      groups.putIfAbsent(s.subjectId, () => []).add(s);
    }

    if (groups.isEmpty) {
      return const SizedBox.shrink();
    }

    final entries = groups.entries.map((e) {
      final subject = e.key != null ? sm.getSubject(e.key) : null;
      final totalMin =
          e.value.fold<int>(0, (sum, s) => sum + s.durationMinutes);
      return _SubjectEntry(
        name: subject?.name ?? 'None',
        color: subject?.color ?? kNoSubjectColor,
        count: e.value.length,
        totalMinutes: totalMin,
      );
    }).toList();

    final maxMinutes =
        entries.fold<int>(0, (m, e) => e.totalMinutes > m ? e.totalMinutes : m);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'By subject',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF3A2E27),
          ),
        ),
        const SizedBox(height: 12),
        for (final entry in entries) ...[
          _SubjectRow(entry: entry, maxMinutes: maxMinutes),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _buildDailyChart(List<PomodoroSession> filtered) {
    final now = DateTime.now();
    final dayCount = _range == _Range.week ? 7 : 30;
    final days = List.generate(
      dayCount,
      (i) => DateTime(now.year, now.month, now.day - (dayCount - 1 - i)),
    );

    final dayMinutes = <DateTime, int>{};
    for (final d in days) {
      dayMinutes[d] = 0;
    }
    for (final s in filtered) {
      final d = DateTime(
          s.completedAt.year, s.completedAt.month, s.completedAt.day);
      if (dayMinutes.containsKey(d)) {
        dayMinutes[d] = dayMinutes[d]! + s.durationMinutes;
      }
    }

    final maxMin = dayMinutes.values.fold<int>(0, (m, v) => v > m ? v : m);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _range == _Range.week
              ? 'Daily breakdown'
              : 'Daily breakdown (30 days)',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF3A2E27),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 140,
          child: _range == _Range.month
              ? ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: days.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 3),
                  itemBuilder: (ctx, i) => _DayBar(
                    minutes: dayMinutes[days[i]]!,
                    maxMinutes: maxMin,
                    label: _shortDate(days[i]),
                    barWidth: 20,
                  ),
                )
              : Row(
                  children: [
                    for (final d in days)
                      Expanded(
                        child: _DayBar(
                          minutes: dayMinutes[d]!,
                          maxMinutes: maxMin,
                          label: _dayLabel(d),
                          barWidth: null,
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildSessionList(
      List<PomodoroSession> filtered, SubjectManager sm) {
    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Text(
            'No sessions today',
            style: TextStyle(
              fontSize: 14,
              color: const Color(0xFF3A2E27).withOpacity(0.4),
            ),
          ),
        ),
      );
    }

    filtered.sort(
        (a, b) => b.completedAt.compareTo(a.completedAt));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Today',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF3A2E27),
          ),
        ),
        const SizedBox(height: 12),
        for (final s in filtered) ...[
          _SessionRow(session: s, sm: sm),
          const SizedBox(height: 6),
        ],
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  const _StatCard({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDDD2C2).withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w300,
              color: Color(0xFF3A2E27),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: const Color(0xFF3A2E27).withOpacity(0.45),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _SubjectEntry {
  final String name;
  final Color color;
  final int count;
  final int totalMinutes;
  const _SubjectEntry({
    required this.name,
    required this.color,
    required this.count,
    required this.totalMinutes,
  });
}

class _SubjectRow extends StatelessWidget {
  final _SubjectEntry entry;
  final int maxMinutes;
  const _SubjectRow({required this.entry, required this.maxMinutes});

  @override
  Widget build(BuildContext context) {
    final fraction = maxMinutes > 0 ? entry.totalMinutes / maxMinutes : 0.0;

    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: entry.color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 80,
          child: Text(
            entry.name,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF3A2E27),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 20,
            decoration: BoxDecoration(
              color: const Color(0xFFF4EFE6),
              borderRadius: BorderRadius.circular(4),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: fraction.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: entry.color.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 70,
          child: Text(
            formatDuration(entry.totalMinutes),
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF3A2E27).withOpacity(0.7),
            ),
          ),
        ),
      ],
    );
  }
}

class _DayBar extends StatelessWidget {
  final int minutes;
  final int maxMinutes;
  final String label;
  final double? barWidth;
  const _DayBar({
    required this.minutes,
    required this.maxMinutes,
    required this.label,
    this.barWidth,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = maxMinutes > 0 ? minutes / maxMinutes : 0.0;

    return Column(
      children: [
        Text(
          minutes > 0 ? formatDuration(minutes) : '',
          style: TextStyle(
            fontSize: 9,
            color: const Color(0xFF3A2E27).withOpacity(0.5),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: barWidth,
          height: 90,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: barWidth ?? double.infinity,
              height: (90 * fraction).clamp(0.0, 90.0),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5A2B)
                    .withOpacity(0.45 + 0.3 * fraction),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(3),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: const Color(0xFF3A2E27).withOpacity(0.5),
          ),
        ),
      ],
    );
  }
}

class _SessionRow extends StatelessWidget {
  final PomodoroSession session;
  final SubjectManager sm;
  const _SessionRow({required this.session, required this.sm});

  String get _timeLabel {
    final t = session.completedAt;
    final hour12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final minute = t.minute.toString().padLeft(2, '0');
    final period = t.hour >= 12 ? 'PM' : 'AM';
    return '$hour12:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final subject =
        session.subjectId != null ? sm.getSubject(session.subjectId) : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDDD2C2).withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: subject?.color ?? kNoSubjectColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _timeLabel,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF3A2E27),
            ),
          ),
          const Spacer(),
          Text(
            '${session.durationMinutes}m',
            style: TextStyle(
              fontSize: 13,
              color: const Color(0xFF3A2E27).withOpacity(0.6),
            ),
          ),
          if (subject != null) ...[
            const SizedBox(width: 8),
            Text(
              subject.name,
              style: TextStyle(
                fontSize: 12,
                color: const Color(0xFF3A2E27).withOpacity(0.45),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
