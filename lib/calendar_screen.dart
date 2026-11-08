import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import 'data.dart';
import 'quicklog.dart';
import 'theme.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _focused = DateTime.now();
  DateTime _selected = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    if (profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final logs = ref.watch(logsProvider);
    final cm = CycleMap(profile);
    final selectedLog = logs[LogsNotifier.keyOf(_selected)];

    return Scaffold(
      appBar: AppBar(
        title: const Text('التقويم'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SelectedDayHeader(
                date: _selected,
                phase: cm.phaseFor(_selected),
                log: selectedLog,
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.nightElevated,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.outline),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                child: TableCalendar(
                  locale: 'ar',
                  firstDay: DateTime.now().subtract(const Duration(days: 365)),
                  lastDay: DateTime.now().add(const Duration(days: 365)),
                  focusedDay: _focused,
                  currentDay: DateTime.now(),
                  selectedDayPredicate: (d) => isSameDay(d, _selected),
                  onDaySelected: (selected, focused) {
                    setState(() {
                      _selected = selected;
                      _focused = focused;
                    });
                  },
                  onPageChanged: (focused) => _focused = focused,
                  calendarFormat: CalendarFormat.month,
                  availableCalendarFormats: const {
                    CalendarFormat.month: 'شهر'
                  },
                  startingDayOfWeek: StartingDayOfWeek.saturday,
                  daysOfWeekStyle: DaysOfWeekStyle(
                    weekdayStyle: T.caption.copyWith(color: AppColors.textMuted),
                    weekendStyle: T.caption.copyWith(color: AppColors.textMuted),
                  ),
                  headerStyle: HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                    titleTextStyle: T.title,
                    leftChevronIcon: const Icon(Icons.chevron_left,
                        color: AppColors.textSecondary),
                    rightChevronIcon: const Icon(Icons.chevron_right,
                        color: AppColors.textSecondary),
                  ),
                  calendarStyle: CalendarStyle(
                    outsideDaysVisible: false,
                    defaultTextStyle:
                        T.body.copyWith(color: AppColors.textPrimary),
                    weekendTextStyle:
                        T.body.copyWith(color: AppColors.textPrimary),
                    todayDecoration: BoxDecoration(
                      color: AppColors.coral.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                    selectedDecoration: const BoxDecoration(
                      color: AppColors.coral,
                      shape: BoxShape.circle,
                    ),
                    selectedTextStyle: T.body.copyWith(
                        color: AppColors.night, fontWeight: FontWeight.w700),
                  ),
                  eventLoader: (day) {
                    final events = <String>[];
                    final log = logs[LogsNotifier.keyOf(day)];
                    if ((log?.bleeding ?? 0) > 0 ||
                        cm.isPredictedPeriod(day)) {
                      events.add('period');
                    }
                    if (cm.isOvulation(day)) {
                      events.add('ovulation');
                    } else if (cm.isFertile(day)) {
                      events.add('fertile');
                    }
                    if (log != null) events.add('log');
                    return events;
                  },
                  calendarBuilders: CalendarBuilders(
                    markerBuilder: (context, day, events) {
                      if (events.isEmpty) return const SizedBox.shrink();
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: events.map((e) {
                          Color c = AppColors.coral;
                          if (e == 'fertile') c = AppColors.sage;
                          if (e == 'ovulation') c = AppColors.cream;
                          if (e == 'log') c = AppColors.textSecondary;
                          return Container(
                            margin:
                                const EdgeInsets.symmetric(horizontal: 1.5),
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const _Legend(),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => QuickLogSheet.show(context, date: _selected),
                icon: const Icon(Icons.edit_outlined, size: 20),
                label: Text(selectedLog == null
                    ? 'أضيفي تسجيل لهذا اليوم'
                    : 'تعديل تسجيل اليوم'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectedDayHeader extends StatelessWidget {
  final DateTime date;
  final String? phase;
  final DailyLog? log;
  const _SelectedDayHeader({
    required this.date,
    required this.phase,
    required this.log,
  });

  String _phaseLabel(String? p) => switch (p) {
        'period' => 'أيام الدورة',
        'follicular' => 'المرحلة الجريبية',
        'fertile' => 'أيام الخصوبة',
        'ovulation' => 'يوم التبويض',
        'luteal' => 'المرحلة الأصفرية',
        _ => 'غير معروف',
      };

  Color _phaseColor(String? p) => switch (p) {
        'period' => AppColors.coral,
        'fertile' => AppColors.sage,
        'ovulation' => AppColors.cream,
        'luteal' => AppColors.plum,
        'follicular' => const Color(0xFF8AA6B8),
        _ => AppColors.outline,
      };

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('EEEE، d MMMM yyyy', 'ar');
    final color = _phaseColor(phase);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.nightElevated,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(df.format(date), style: T.title),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: color.withValues(alpha: 0.4)),
                ),
                child: Text(
                  _phaseLabel(phase),
                  style: T.caption.copyWith(
                      color: color, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          if (log != null) ...[
            const SizedBox(height: 14),
            const Divider(color: AppColors.outline, height: 1),
            const SizedBox(height: 14),
            _logRow(context, log!),
          ] else ...[
            const SizedBox(height: 10),
            Text('مفيش تسجيل لليوم ده.',
                style: T.body.copyWith(color: AppColors.textMuted)),
          ],
        ],
      ),
    );
  }

  Widget _logRow(BuildContext context, DailyLog log) {
    const bleedLabels = ['', 'خفيف', 'متوسط', 'غزير'];
    final bits = <String>[];
    if (log.bleeding > 0) bits.add('نزيف ${bleedLabels[log.bleeding]}');
    if (log.moods.isNotEmpty) bits.add('مزاج: ${log.moods.join(" • ")}');
    if (log.pain > 0) bits.add('ألم: ${painLabel(log.pain)}');
    bits.add('نوم: ${log.sleepHours.toStringAsFixed(1)}س');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...bits.map((b) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('• $b', style: T.body),
            )),
        if (log.notes != null && log.notes!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text('"${log.notes!}"',
              style: T.body.copyWith(
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              )),
        ],
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    Widget item(Color c, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: c, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(label,
                style: T.caption.copyWith(color: AppColors.textSecondary)),
          ],
        );

    return Wrap(
      spacing: 16,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        item(AppColors.coral, 'دورة'),
        item(AppColors.sage, 'خصوبة'),
        item(AppColors.cream, 'تبويض'),
        item(AppColors.textSecondary, 'تسجيل'),
      ],
    );
  }
}