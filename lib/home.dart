import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'data.dart';
import 'quicklog.dart';
import 'theme.dart';

Color _phaseColor(String phase) => switch (phase) {
      'menstrual' => AppColors.coral,
      'follicular' => const Color(0xFF8AA6B8),
      'fertile' => AppColors.sage,
      'ovulation' => AppColors.cream,
      'luteal' => AppColors.plum,
      _ => AppColors.coral,
    };

String _phaseLabel(String phase) => switch (phase) {
      'menstrual' => 'أيام الدورة',
      'follicular' => 'المرحلة الجريبية',
      'fertile' => 'أيام الخصوبة',
      'ovulation' => 'يوم التبويض',
      'luteal' => 'المرحلة الأصفرية',
      _ => '',
    };

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    if (profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final p = CyclePrediction.from(profile);
    final df = DateFormat('EEEE، d MMMM', 'ar');
    final dfShort = DateFormat('d MMM', 'ar');
    final color = _phaseColor(p.phase);
    final todayLog =
        ref.watch(logsProvider)[LogsNotifier.keyOf(DateTime.now())];

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('اليوم',
                            style: T.caption
                                .copyWith(color: AppColors.textMuted)),
                        const SizedBox(height: 2),
                        Text(df.format(DateTime.now()), style: T.title),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: color.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      _phaseLabel(p.phase),
                      style: T.caption.copyWith(
                          color: color, fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    tooltip: 'التقويم',
                    onPressed: () => context.push('/calendar'),
                    icon: const Icon(Icons.calendar_month_outlined,
                        color: AppColors.textSecondary),
                  ),
                  IconButton(
                    tooltip: 'الرؤى',
                    onPressed: () => context.push('/insights'),
                    icon: const Icon(Icons.insights,
                        color: AppColors.textSecondary),
                  ),
                  IconButton(
                    tooltip: 'الإعدادات',
                    onPressed: () => context.push('/settings'),
                    icon: const Icon(Icons.settings_outlined,
                        color: AppColors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Center(
                child: SizedBox(
                  width: 280,
                  height: 280,
                  child: CustomPaint(
                    painter: _RingPainter(
                      progress: p.cycleProgress.clamp(0.02, 1.0),
                      color: color,
                      track: AppColors.outline,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'اليوم ${p.dayInCycle}',
                            style: T.caption.copyWith(
                                color: AppColors.textSecondary,
                                letterSpacing: 1),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${p.daysUntilNextPeriod}',
                            style:
                                T.display.copyWith(fontSize: 64, height: 1),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'يوم للدورة',
                            style: T.body
                                .copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: _InfoCard(
                      icon: Icons.water_drop_outlined,
                      label: 'الدورة القادمة',
                      value: dfShort.format(p.nextPeriodStart),
                      color: AppColors.coral,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _InfoCard(
                      icon: Icons.spa_outlined,
                      label: 'التبويض',
                      value: dfShort.format(p.ovulationDay),
                      color: AppColors.sage,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Text('سجّلي بسرعة', style: T.title),
              const SizedBox(height: 12),
              Row(
                children: [
                  _QuickAction(
                    icon: Icons.water_drop,
                    label: 'نزيف',
                    color: AppColors.coral,
                    onTap: () => QuickLogSheet.show(context),
                  ),
                  _QuickAction(
                    icon: Icons.mood,
                    label: 'مزاج',
                    color: const Color(0xFFE8C77A),
                    onTap: () => QuickLogSheet.show(context),
                  ),
                  _QuickAction(
                    icon: Icons.bolt,
                    label: 'ألم',
                    color: const Color(0xFFC98AA8),
                    onTap: () => QuickLogSheet.show(context),
                  ),
                  _QuickAction(
                    icon: Icons.bedtime_outlined,
                    label: 'نوم',
                    color: AppColors.sage,
                    onTap: () => QuickLogSheet.show(context),
                  ),
                ],
              ),
              if (todayLog != null) ...[
                const SizedBox(height: 20),
                _TodaySummary(log: todayLog),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TodaySummary extends StatelessWidget {
  final DailyLog log;
  const _TodaySummary({required this.log});

  @override
  Widget build(BuildContext context) {
    const bleedLabels = ['', 'خفيف', 'متوسط', 'غزير'];
    final bits = <String>[];
    if (log.bleeding > 0) bits.add('نزيف ${bleedLabels[log.bleeding]}');
    if (log.moods.isNotEmpty) bits.add('${log.moods.length} مزاج');
    if (log.pain > 0) bits.add('ألم ${painLabel(log.pain)}');
    bits.add('نوم ${log.sleepHours.toStringAsFixed(1)}س');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.plum.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.coral.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: AppColors.coral, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('سجلتي النهاردة',
                    style: T.title.copyWith(fontSize: 14)),
                const SizedBox(height: 2),
                Text(bits.join(' • '),
                    style:
                        T.caption.copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
          TextButton(
            onPressed: () => QuickLogSheet.show(context),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.coral,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 32),
            ),
            child: const Text('تعديل'),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.nightElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 12),
          Text(label, style: T.caption.copyWith(color: AppColors.textMuted)),
          const SizedBox(height: 4),
          Text(value, style: T.title),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.nightElevated,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.outline),
            ),
            child: Column(
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(height: 8),
                Text(label,
                    style: T.caption.copyWith(color: AppColors.textPrimary)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color track;

  _RingPainter({
    required this.progress,
    required this.color,
    required this.track,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 18.0;
    final center = size.center(Offset.zero);
    final radius = (size.width - stroke) / 2;

    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;

    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(
        rect, -math.pi / 2, 2 * math.pi * progress, false, progressPaint);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress || old.color != color || old.track != track;
}