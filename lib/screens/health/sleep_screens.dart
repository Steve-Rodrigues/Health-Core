import 'package:flutter/material.dart';

import '../../services/api.dart';

// Same palette as health_screen.dart.
const _navy = Color(0xFF062D63);
const _blue = Color(0xFF086AC7);
const _paleBlue = Color(0xFFE5F4FF);
const _lightBlue = Color(0xFFC2DFF2);
const _accent = Color(0xFF36B9FF);

const _weekdayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
const _weekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];
const _qualityLabels = ['Very poor', 'Poor', 'Okay', 'Good', 'Great'];

// ---------------------------------------------------------------------------
// Small helpers shared by the sleep screens
// ---------------------------------------------------------------------------

DateTime _today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

DateTime _parseDate(Object? value) {
  final parsed = DateTime.parse(value as String);
  return DateTime(parsed.year, parsed.month, parsed.day);
}

/// Parses "23:30" or "23:30:00" from the backend.
TimeOfDay? _parseTime(Object? value) {
  if (value is! String) return null;
  final parts = value.split(':');
  if (parts.length < 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return null;
  return TimeOfDay(hour: hour, minute: minute);
}

/// 24-hour "HH:MM", the format the backend expects.
String _apiTime(TimeOfDay value) =>
    '${value.hour.toString().padLeft(2, '0')}:'
    '${value.minute.toString().padLeft(2, '0')}';

String _displayTime(BuildContext context, TimeOfDay? value) =>
    value == null ? '--' : MaterialLocalizations.of(context).formatTimeOfDay(value);

String _hoursAndMinutes(int totalMinutes) {
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  if (hours == 0) return '${minutes}m';
  return minutes == 0 ? '${hours}h' : '${hours}h ${minutes}m';
}

String _formatHours(num? hours) {
  if (hours == null) return '--';
  return _hoursAndMinutes((hours * 60).round());
}

String _friendlyDate(DateTime date) {
  final today = _today();
  final difference = today.difference(date).inDays;
  if (difference == 0) return 'Today';
  if (difference == 1) return 'Yesterday';
  return '${_weekdayNames[date.weekday - 1]}, '
      '${_monthNames[date.month - 1]} ${date.day}';
}

/// Minutes slept, matching the backend: if bed time is at or after wake time,
/// the user went to bed the night before.
int _durationMinutes(TimeOfDay bed, TimeOfDay wake) {
  final bedMinutes = bed.hour * 60 + bed.minute;
  final wakeMinutes = wake.hour * 60 + wake.minute;
  var difference = wakeMinutes - bedMinutes;
  if (difference <= 0) difference += 24 * 60;
  return difference;
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

void _showError(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
  );
}

// -----------------------
// Sleep Dashboard Section
// -----------------------

class SleepTrackerScreen extends StatefulWidget {
  const SleepTrackerScreen({super.key});

  @override
  State<SleepTrackerScreen> createState() => _SleepTrackerScreenState();
}

class _SleepTrackerScreenState extends State<SleepTrackerScreen> {
  final _api = ApiClient();
  int _rangeDays = 7;
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _summary;
  List<Map<String, dynamic>> _logs = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// This method loads the summary and history. The first load shows a spinner; later
  /// reloads keep the current data on screen until the new data arrives.
  Future<void> _load() async {
    _error = null;
    try {
      final today = _today();
      final results = await Future.wait([
        _api.getSleepSummary(currentDate: today, days: _rangeDays),
        _api.getSleepLogs(endDate: today),
      ]);
      if (!mounted) return;
      setState(() {
        _summary = results[0] as Map<String, dynamic>;
        _logs = results[1] as List<Map<String, dynamic>>;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      if (_summary == null) {
        setState(() => _error = error.message);
      } else {
        _showError(context, error.message);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _changeRange(int days) async {
    if (days == _rangeDays) return;
    setState(() => _rangeDays = days);
    await _load();
  }

  bool get _loggedToday =>
      _logs.any((log) => _sameDay(_parseDate(log['sleep_date']), _today()));

  Future<void> _openEntry([Map<String, dynamic>? existing]) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => SleepEntryScreen(
          existing: existing,
          takenDates: _logs.map((log) => _parseDate(log['sleep_date'])).toList(),
        ),
      ),
    );
    if (saved == true) await _load();
  }

  Future<bool> _confirmDelete(Map<String, dynamic> log) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this night?'),
        content: Text(
          'Your sleep entry for ${_friendlyDate(_parseDate(log['sleep_date']))} '
          'will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return false;
    try {
      await _api.deleteSleep(log['id'] as String);
      return true;
    } on ApiException catch (error) {
      if (mounted) _showError(context, error.message);
      return false;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _navy,
    appBar: AppBar(title: const Text('Sleep Tracker'), backgroundColor: _navy),
    floatingActionButton: _summary == null
        ? null
        : FloatingActionButton.extended(
            onPressed: () => _openEntry(),
            backgroundColor: _accent,
            foregroundColor: _navy,
            icon: const Icon(Icons.add_rounded),
            label: Text(_loggedToday ? 'Log a night' : 'Log last night'),
          ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _summary == null
        ? _ErrorState(
            message: _error ?? 'Something went wrong.',
            onRetry: () {
              setState(() => _loading = true);
              _load();
            },
          )
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
              children: [
                const Text(
                  'Rest is part of progress.',
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Georgia',
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _RangePicker(days: _rangeDays, onChanged: _changeRange),
                const SizedBox(height: 16),
                _SummaryCard(summary: _summary!),
                const SizedBox(height: 14),
                _SleepChartCard(summary: _summary!),
                const SizedBox(height: 14),
                _ScheduleCard(summary: _summary!),
                const SizedBox(height: 14),
                _TipsLink(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SleepTipsScreen()),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Last 30 days',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Tap a night to edit it, or swipe left to delete it.',
                  style: TextStyle(color: _lightBlue, fontSize: 13),
                ),
                const SizedBox(height: 12),
                if (_logs.isEmpty)
                  const _EmptyHistory()
                else
                  for (final log in _logs) ...[
                    Dismissible(
                      key: ValueKey(log['id']),
                      direction: DismissDirection.endToStart,
                      confirmDismiss: (_) => _confirmDelete(log),
                      onDismissed: (_) {
                        setState(() => _logs.remove(log));
                        _load();
                      },
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 24),
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.delete_outline_rounded,
                          color: Colors.white,
                        ),
                      ),
                      child: _SleepLogTile(
                        log: log,
                        goalHours: (_summary!['sleep_goal_hours'] as num?)
                            ?.toDouble(),
                        onTap: () => _openEntry(log),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
              ],
            ),
          ),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, color: _lightBlue, size: 48),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    ),
  );
}

class _RangePicker extends StatelessWidget {
  const _RangePicker({required this.days, required this.onChanged});

  final int days;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => SegmentedButton<int>(
    segments: const [
      ButtonSegment(value: 7, label: Text('7 days')),
      ButtonSegment(value: 30, label: Text('30 days')),
    ],
    selected: {days},
    showSelectedIcon: false,
    onSelectionChanged: (selection) => onChanged(selection.first),
    style: SegmentedButton.styleFrom(
      backgroundColor: _navy,
      foregroundColor: _lightBlue,
      selectedBackgroundColor: _paleBlue,
      selectedForegroundColor: _navy,
      side: const BorderSide(color: _lightBlue),
    ),
  );
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: _paleBlue,
      borderRadius: BorderRadius.circular(22),
    ),
    child: child,
  );
}

class _CardTitle extends StatelessWidget {
  const _CardTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: _navy,
      fontSize: 16,
      fontWeight: FontWeight.bold,
    ),
  );
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});

  final Map<String, dynamic> summary;

  @override
  Widget build(BuildContext context) {
    final nightsLogged = summary['nights_logged'] as int? ?? 0;
    final days = summary['days'] as int? ?? 7;
    final avgHours = (summary['avg_duration_hours'] as num?)?.toDouble();
    final goalHours = (summary['sleep_goal_hours'] as num?)?.toDouble();
    final avgQuality = (summary['avg_quality'] as num?)?.toDouble();
    final nightsOnGoal = summary['nights_meeting_goal'] as int?;
    final debt = (summary['sleep_debt_hours'] as num?)?.toDouble();
    final streak = summary['logging_streak'] as int? ?? 0;
    final progress = (avgHours != null && goalHours != null && goalHours > 0)
        ? (avgHours / goalHours).clamp(0.0, 1.0)
        : null;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Average per night · last $days days',
            style: const TextStyle(color: Colors.black54, fontSize: 13),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatHours(avgHours),
                style: const TextStyle(
                  color: _navy,
                  fontFamily: 'Georgia',
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 10),
              if (goalHours != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    'of ${_formatHours(goalHours)} goal',
                    style: const TextStyle(color: Colors.black54),
                  ),
                ),
            ],
          ),
          if (progress != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 10,
                backgroundColor: _lightBlue,
                color: progress >= 1 ? Colors.green : _blue,
              ),
            ),
          ],
          if (goalHours == null) ...[
            const SizedBox(height: 8),
            const Text(
              'Set a sleep goal in your fitness goals to track progress.',
              style: TextStyle(color: Colors.black54, fontSize: 13),
            ),
          ],
          if (nightsLogged == 0) ...[
            const SizedBox(height: 8),
            const Text(
              'No nights logged in this range yet.',
              style: TextStyle(color: Colors.black54, fontSize: 13),
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _StatChip(
                icon: Icons.star_rounded,
                label: 'Avg quality',
                value: avgQuality == null ? '--' : '${avgQuality.toStringAsFixed(1)} / 5',
              ),
              _StatChip(
                icon: Icons.flag_rounded,
                label: 'Nights on goal',
                value: nightsOnGoal == null ? '--' : '$nightsOnGoal / $nightsLogged',
              ),
              _StatChip(
                icon: Icons.hourglass_bottom_rounded,
                label: 'Sleep debt',
                value: debt == null ? '--' : _formatHours(debt),
              ),
              _StatChip(
                icon: Icons.local_fire_department_rounded,
                label: 'Logging streak',
                value: '$streak ${streak == 1 ? 'night' : 'nights'}',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    width: 140,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        Icon(icon, color: _blue, size: 22),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: _navy,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: const TextStyle(color: Colors.black54, fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Bar chart of hours slept for every day in the range, with the goal drawn
/// as a line. Days that weren't logged show as a short faded stub.
class _SleepChartCard extends StatelessWidget {
  const _SleepChartCard({required this.summary});

  final Map<String, dynamic> summary;

  @override
  Widget build(BuildContext context) {
    final start = _parseDate(summary['start_date']);
    final days = summary['days'] as int? ?? 7;
    final goalHours = (summary['sleep_goal_hours'] as num?)?.toDouble();
    final byDate = <DateTime, Map<String, dynamic>>{};
    for (final night in (summary['nights'] as List? ?? [])
        .whereType<Map<String, dynamic>>()) {
      byDate[_parseDate(night['sleep_date'])] = night;
    }
    final dates = [
      for (var i = 0; i < days; i++)
        DateTime(start.year, start.month, start.day + i),
    ];
    var maxHours = goalHours ?? 8.0;
    for (final night in byDate.values) {
      final hours = (night['duration_hours'] as num).toDouble();
      if (hours > maxHours) maxHours = hours;
    }
    maxHours = (maxHours + 1).ceilToDouble();
    const chartHeight = 140.0;
    final compact = days > 10;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle('Hours slept'),
          const SizedBox(height: 14),
          SizedBox(
            height: chartHeight,
            child: Stack(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final date in dates)
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: compact ? 1 : 5,
                          ),
                          child: _Bar(
                            night: byDate[date],
                            maxHours: maxHours,
                            height: chartHeight,
                          ),
                        ),
                      ),
                  ],
                ),
                if (goalHours != null)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: chartHeight * (goalHours / maxHours),
                    child: Container(height: 2, color: _navy.withValues(alpha: 0.5)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              for (var i = 0; i < dates.length; i++)
                Expanded(
                  child: Text(
                    compact
                        ? (i % 5 == 0 || i == dates.length - 1
                              ? '${dates[i].day}'
                              : '')
                        : _weekdayLetters[dates[i].weekday - 1],
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.visible,
                    softWrap: false,
                    style: const TextStyle(color: Colors.black54, fontSize: 11),
                  ),
                ),
            ],
          ),
          if (goalHours != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Container(width: 18, height: 2, color: _navy.withValues(alpha: 0.5)),
                const SizedBox(width: 6),
                Text(
                  'Goal (${_formatHours(goalHours)})',
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
                const SizedBox(width: 16),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'Goal met',
                  style: TextStyle(color: Colors.black54, fontSize: 12),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.night, required this.maxHours, required this.height});

  final Map<String, dynamic>? night;
  final double maxHours;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (night == null) {
      return Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          height: 4,
          decoration: BoxDecoration(
            color: _lightBlue,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );
    }
    final hours = (night!['duration_hours'] as num).toDouble();
    final metGoal = night!['met_goal'] as bool?;
    return Tooltip(
      message: '${_formatHours(hours)} · quality ${night!['quality']}/5',
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          height: (height * (hours / maxHours)).clamp(4.0, height),
          decoration: BoxDecoration(
            color: metGoal == true ? Colors.green : _blue,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          ),
        ),
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({required this.summary});

  final Map<String, dynamic> summary;

  (String, Color) _consistencyLabel(int? minutes) {
    if (minutes == null) return ('Not enough data', Colors.black54);
    if (minutes <= 30) return ('Very steady', Colors.green);
    if (minutes <= 60) return ('Fairly steady', _blue);
    return ('Irregular', Colors.deepOrange);
  }

  @override
  Widget build(BuildContext context) {
    final bed = _parseTime(summary['avg_bed_time']);
    final wake = _parseTime(summary['avg_wake_time']);
    final consistency = summary['bed_time_consistency_mins'] as int?;
    final (label, color) = _consistencyLabel(consistency);

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle('Sleep schedule'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ScheduleValue(
                  icon: Icons.bedtime_rounded,
                  label: 'Avg bed time',
                  value: _displayTime(context, bed),
                ),
              ),
              Expanded(
                child: _ScheduleValue(
                  icon: Icons.wb_sunny_rounded,
                  label: 'Avg wake time',
                  value: _displayTime(context, wake),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(Icons.schedule_rounded, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: label,
                        style: TextStyle(color: color, fontWeight: FontWeight.bold),
                      ),
                      if (consistency != null)
                        TextSpan(
                          text: ' · bed time varies by about $consistency min',
                          style: const TextStyle(color: Colors.black54),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScheduleValue extends StatelessWidget {
  const _ScheduleValue({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      CircleAvatar(
        backgroundColor: Colors.white,
        foregroundColor: _blue,
        child: Icon(icon),
      ),
      const SizedBox(width: 10),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: _navy,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(label, style: const TextStyle(color: Colors.black54, fontSize: 12)),
        ],
      ),
    ],
  );
}

class _TipsLink extends StatelessWidget {
  const _TipsLink({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: _paleBlue,
    borderRadius: BorderRadius.circular(22),
    child: ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      leading: const CircleAvatar(
        backgroundColor: _blue,
        foregroundColor: Colors.white,
        child: Icon(Icons.tips_and_updates_outlined),
      ),
      title: const Text(
        'Sleep tips',
        style: TextStyle(color: _navy, fontWeight: FontWeight.bold),
      ),
      subtitle: const Text('Simple habits for better rest.'),
      trailing: const Icon(Icons.chevron_right_rounded, color: _blue),
      onTap: onTap,
    ),
  );
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) => const _Card(
    child: Row(
      children: [
        Icon(Icons.nightlight_round, color: _blue),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            'No sleep logged yet. Log last night to start building your history.',
            style: TextStyle(color: _navy),
          ),
        ),
      ],
    ),
  );
}

class _SleepLogTile extends StatelessWidget {
  const _SleepLogTile({
    required this.log,
    required this.goalHours,
    required this.onTap,
  });

  final Map<String, dynamic> log;
  final double? goalHours;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final date = _parseDate(log['sleep_date']);
    final hours = (log['duration_hours'] as num?)?.toDouble() ?? 0;
    final quality = log['quality'] as int? ?? 0;
    final notes = (log['notes'] as String?)?.trim() ?? '';
    final metGoal = goalHours != null && hours >= goalHours!;

    return Material(
      color: _paleBlue,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: metGoal ? Colors.green : _blue,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    Text(
                      _weekdayNames[date.weekday - 1],
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                    Text(
                      '${date.day}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _formatHours(hours),
                            style: const TextStyle(
                              color: _navy,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        for (var i = 1; i <= 5; i++)
                          Icon(
                            i <= quality ? Icons.star_rounded : Icons.star_border_rounded,
                            color: Colors.amber.shade700,
                            size: 16,
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_friendlyDate(date)} · '
                      '${_displayTime(context, _parseTime(log['bed_time']))} – '
                      '${_displayTime(context, _parseTime(log['wake_time']))}',
                      style: const TextStyle(color: Colors.black54, fontSize: 13),
                    ),
                    if (notes.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        notes,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.black87, fontSize: 13),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ----------------------------------
// Log / edit a night that you slept.
// ----------------------------------

/// Logs a new night, or edits [existing] when it is given. Pops `true` after
/// a save or delete so the dashboard knows to reload.
class SleepEntryScreen extends StatefulWidget {
  const SleepEntryScreen({super.key, this.existing, this.takenDates = const []});

  final Map<String, dynamic>? existing;

  /// Days that already have an entry, so the user is warned before saving.
  final List<DateTime> takenDates;

  @override
  State<SleepEntryScreen> createState() => _SleepEntryScreenState();
}

class _SleepEntryScreenState extends State<SleepEntryScreen> {
  final _api = ApiClient();
  final _notes = TextEditingController();
  late DateTime _wakeDate;
  TimeOfDay _bed = const TimeOfDay(hour: 23, minute: 0);
  TimeOfDay _wake = const TimeOfDay(hour: 7, minute: 0);
  int _quality = 4;
  bool _saving = false;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing == null) {
      _wakeDate = _today();
      // If today is already logged, start on the most recent free day.
      while (widget.takenDates.any((d) => _sameDay(d, _wakeDate))) {
        _wakeDate = DateTime(_wakeDate.year, _wakeDate.month, _wakeDate.day - 1);
      }
    } else {
      _wakeDate = _parseDate(existing['sleep_date']);
      _bed = _parseTime(existing['bed_time']) ?? _bed;
      _wake = _parseTime(existing['wake_time']) ?? _wake;
      _quality = existing['quality'] as int? ?? _quality;
      _notes.text = existing['notes'] as String? ?? '';
    }
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  bool get _dateTaken {
    final original = widget.existing == null
        ? null
        : _parseDate(widget.existing!['sleep_date']);
    if (original != null && _sameDay(original, _wakeDate)) return false;
    return widget.takenDates.any((d) => _sameDay(d, _wakeDate));
  }

  Future<void> _pickDate() async {
    final today = _today();
    final picked = await showDatePicker(
      context: context,
      initialDate: _wakeDate,
      firstDate: DateTime(today.year - 1, today.month, today.day),
      lastDate: today,
      helpText: 'Which morning did you wake up?',
    );
    if (picked != null && mounted) setState(() => _wakeDate = picked);
  }

  Future<void> _pickTime(bool bed) async {
    final value = await showTimePicker(
      context: context,
      initialTime: bed ? _bed : _wake,
    );
    if (value == null || !mounted) return;
    setState(() {
      if (bed) {
        _bed = value;
      } else {
        _wake = value;
      }
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      if (_editing) {
        await _api.updateSleep(
          sleepId: widget.existing!['id'] as String,
          wakeDate: _wakeDate,
          bedTime: _apiTime(_bed),
          wakeTime: _apiTime(_wake),
          quality: _quality,
          notes: _notes.text,
        );
      } else {
        await _api.logSleep(
          wakeDate: _wakeDate,
          bedTime: _apiTime(_bed),
          wakeTime: _apiTime(_wake),
          quality: _quality,
          notes: _notes.text,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_editing ? 'Sleep entry updated.' : 'Sleep logged.')),
      );
      Navigator.pop(context, true);
    } on ApiException catch (error) {
      if (mounted) _showError(context, error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this night?'),
        content: const Text('This sleep entry will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await _api.deleteSleep(widget.existing!['id'] as String);
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (error) {
      if (mounted) _showError(context, error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final minutes = _durationMinutes(_bed, _wake);
    return Scaffold(
      backgroundColor: _navy,
      appBar: AppBar(
        title: Text(_editing ? 'Edit night' : 'Log sleep'),
        backgroundColor: _navy,
        actions: [
          if (_editing)
            IconButton(
              tooltip: 'Delete',
              onPressed: _saving ? null : _delete,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          _PickerTile(
            icon: Icons.calendar_today_rounded,
            label: 'Woke up on',
            value: _friendlyDate(_wakeDate),
            onTap: _pickDate,
          ),
          if (_dateTaken) ...[
            const SizedBox(height: 6),
            const Text(
              'You already logged this day. Edit that entry from the history list instead.',
              style: TextStyle(color: Colors.orangeAccent, fontSize: 13),
            ),
          ],
          const SizedBox(height: 10),
          _PickerTile(
            icon: Icons.bedtime_rounded,
            label: 'Bed time',
            value: _displayTime(context, _bed),
            onTap: () => _pickTime(true),
          ),
          const SizedBox(height: 10),
          _PickerTile(
            icon: Icons.wb_sunny_rounded,
            label: 'Wake time',
            value: _displayTime(context, _wake),
            onTap: () => _pickTime(false),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
            decoration: BoxDecoration(
              color: _blue,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                const Icon(Icons.nightlight_round, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'You slept ${_hoursAndMinutes(minutes)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (minutes > 14 * 60) ...[
            const SizedBox(height: 6),
            const Text(
              'That is over 14 hours. Double-check your bed and wake times.',
              style: TextStyle(color: Colors.orangeAccent, fontSize: 13),
            ),
          ],
          const SizedBox(height: 14),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _CardTitle('How did you sleep?'),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var i = 1; i <= 5; i++)
                      ChoiceChip(
                        label: Text('$i · ${_qualityLabels[i - 1]}'),
                        selected: _quality == i,
                        selectedColor: _blue,
                        labelStyle: TextStyle(
                          color: _quality == i ? Colors.white : _navy,
                          fontWeight: FontWeight.w600,
                        ),
                        showCheckmark: false,
                        onSelected: (_) => setState(() => _quality = i),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _notes,
                  maxLines: 3,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    hintText: 'Woke up once, late caffeine, felt rested...',
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _saving || _dateTaken ? null : _save,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            child: _saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : Text(_editing ? 'Save changes' : 'Log sleep'),
          ),
        ],
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: _paleBlue,
    borderRadius: BorderRadius.circular(18),
    child: ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      leading: Icon(icon, color: _blue),
      title: Text(
        label,
        style: const TextStyle(color: _navy, fontWeight: FontWeight.bold),
      ),
      trailing: Text(
        value,
        style: const TextStyle(
          color: _blue,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      onTap: onTap,
    ),
  );
}

// -------------------
// Sleep tips for user
// -------------------

class SleepTipsScreen extends StatelessWidget {
  const SleepTipsScreen({super.key});

  static const _tips = [
    (
      'Keep a steady schedule',
      'Go to bed and wake up at about the same time every day, weekends included. Your bed time consistency on the tracker shows how steady you are.',
      Icons.schedule_rounded,
    ),
    (
      'Build a wind-down routine',
      'Spend the last 30–60 minutes before bed on something calm, like reading, stretching or a warm shower, and dim the lights.',
      Icons.self_improvement_rounded,
    ),
    (
      'Limit screens before bed',
      'Bright screens and scrolling keep your brain alert. Try putting your phone away or switching on night mode an hour before bed.',
      Icons.phone_iphone_rounded,
    ),
    (
      'Watch caffeine and alcohol',
      'Caffeine can stay in your system for hours, so avoid it in the afternoon. Alcohol may make you drowsy but tends to break up sleep later in the night.',
      Icons.local_cafe_outlined,
    ),
    (
      'Make your room sleep-friendly',
      'Keep your bedroom cool, dark and quiet. Blackout curtains, earplugs or a fan can help.',
      Icons.bed_outlined,
    ),
    (
      'Time your workouts',
      'Regular exercise helps you sleep, but a hard session right before bed can make it harder to fall asleep. Aim to finish a few hours earlier.',
      Icons.fitness_center_rounded,
    ),
    (
      'Get morning light',
      'Natural light soon after waking helps set your body clock, which makes it easier to feel sleepy at night.',
      Icons.wb_sunny_outlined,
    ),
    (
      'Keep naps short',
      'If you nap, keep it to about 20–30 minutes and earlier in the day so it doesn\'t cut into your night sleep.',
      Icons.snooze_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _navy,
    appBar: AppBar(title: const Text('Sleep Tips'), backgroundColor: _navy),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
      children: [
        const Text(
          'Small habits that add up to better rest.',
          style: TextStyle(color: _lightBlue, fontSize: 15),
        ),
        const SizedBox(height: 12),
        const Text(
          'If you regularly struggle to sleep or feel tired even after a full night, talk to a doctor.',
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 18),
        for (final tip in _tips) ...[
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: ExpansionTile(
              shape: const RoundedRectangleBorder(side: BorderSide.none),
              leading: CircleAvatar(
                backgroundColor: _paleBlue,
                foregroundColor: _blue,
                child: Icon(tip.$3),
              ),
              title: Text(
                tip.$1,
                style: const TextStyle(color: _navy, fontWeight: FontWeight.bold),
              ),
              childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              children: [
                Text(
                  tip.$2,
                  style: const TextStyle(color: Colors.black87, height: 1.45),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    ),
  );
}
