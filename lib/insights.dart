import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data.dart';
import 'theme.dart';

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final logs = ref.watch(logsProvider);

    if (profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final sorted = logs.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final stats = InsightsData(profile: profile, logs: sorted);

    return Scaffold(
      appBar: AppBar(title: const Text('الرؤى')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _StreakCard(stats: stats),
              const SizedBox(height: 16),
              if (sorted.isEmpty)
                const _EmptyState()
              else ...[
                _StatsGrid(stats: stats),
                const SizedBox(height: 20),
                _PainChart(stats: stats),
                const SizedBox(height: 20),
                _PatternsCard(stats: stats),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------- insights engine ----------------

class InsightsData {
  final UserProfile profile;
  final List<DailyLog> logs;
  InsightsData({required this.profile, required this.logs});

  int get totalLoggedDays => logs.length;

  int get currentStreak {
    if (logs.isEmpty) return 0;
    final today = DateUtils.dateOnly(DateTime.now());
    final dates = logs.map((l) => DateUtils.dateOnly(l.date)).toSet();
    var d = today;
    if (!dates.contains(today)) {
      d = today.subtract(const Duration(days: 1));
    }
    var streak = 0;
    while (dates.contains(d)) {
      streak++;
      d = d.subtract(const Duration(days: 1));
    }
    return streak;
  }

  double get avgPain {
    final withPain = logs.where((l) => l.pain > 0).toList();
    if (withPain.isEmpty) return 0;
    final sum = withPain.map((l) => l.pain).reduce((a, b) => a + b);
    return sum / withPain.length;
  }

  double get avgSleep {
    if (logs.isEmpty) return 0;
    final sum = logs.map((l) => l.sleepHours).reduce((a, b) => a + b);
    return sum / logs.length;
  }

  Map<String, int> get moodFrequency {
    final m = <String, int>{};
    for (final l in logs) {
      for (final mood in l.moods) {
        m[mood] = (m[mood] ?? 0) + 1;
      }
    }
    return m;
  }

  String? get topMood {
    final m = moodFrequency;
    if (m.isEmpty) return null;
    return m.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  double painInPhase(String phase) {
    final cm = CycleMap(profile);
    final list = logs
        .where((l) => cm.phaseFor(l.date) == phase && l.pain > 0)
        .toList();
    if (list.isEmpty) return 0;
    final sum = list.map((l) => l.pain).reduce((a, b) => a + b);
    return sum / list.length;
  }

  double get avgSleepPremenstrual {
    final cm = CycleMap(profile);
    final start = DateUtils.dateOnly(profile.lastPeriodStart);
    final relevant = logs.where((l) {
      final d = DateUtils.dateOnly(l.date);
      final diff = d.difference(start).inDays;
      if (diff < 0) return false;
      final day = (diff % profile.cycleLength) + 1;
      return day > profile.cycleLength - 4 && day <= profile.cycleLength;
    }).toList();
    if (relevant.isEmpty) return 0;
    final sum = relevant.map((l) => l.sleepHours).reduce((a, b) => a + b);
    return sum / relevant.length;
  }

  List<String> get patterns {
    final list = <String>[];

    final pPain = painInPhase('period');
    if (pPain > 0 && pPain >= avgPain && pPain > 0.5) {
      list.add(
          'أعلى ألم عندك في أيام الدورة (متوسط ${pPain.toStringAsFixed(1)} من 5).');
    }

    final preSleep = avgSleepPremenstrual;
    if (preSleep > 0 && avgSleep > 0) {
      final diff = avgSleep - preSleep;
      if (diff.abs() >= 0.5) {
        if (diff > 0) {
          list.add(
              'نومك أقل قبل الدورة بحوالي ${diff.toStringAsFixed(1)} ساعة.');
        } else {
          list.add(
              'نومك أحسن قبل الدورة بحوالي ${(-diff).toStringAsFixed(1)} ساعة.');
        }
      }
    }

    final mood = topMood;
    if (mood != null) {
      final count = moodFrequency[mood] ?? 0;
      list.add('أكثر مزاج بيتكرر عندك: "$mood" ($count مرة).');
    }

    if (totalLoggedDays >= 5) {
      list.add('سجلتي $totalLoggedDays يوم — كل تسجيل بيخلي التوقعات أدق.');
    }

    return list;
  }

  List<DailyLog> get recentLogs {
    if (logs.length <= 14) return logs;
    return logs.sublist(logs.length - 14);
  }
}

// ---------------- widgets ----------------

class _StreakCard extends StatelessWidget {
  final InsightsData stats;
  const _StreakCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.plum, Color(0xFF2A162E)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.coral.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.local_fire_department,
                        color: AppColors.coral, size: 20),
                    const SizedBox(width: 6),
                    Text('سلسلة التسجيل',
                        style: T.caption
                            .copyWith(color: AppColors.textSecondary)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${stats.currentStreak}',
                  style: T.display.copyWith(fontSize: 44, height: 1),
                ),
                Text(
                  'أيام متتالية',
                  style: T.body.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${stats.totalLoggedDays}',
                  style: T.headline.copyWith(color: AppColors.coral)),
              Text('إجمالي التسجيلات',
                  style: T.caption.copyWith(color: AppColors.textMuted)),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final InsightsData stats;
  const _StatsGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.bolt,
            label: 'متوسط الألم',
            value:
                stats.avgPain > 0 ? stats.avgPain.toStringAsFixed(1) : '—',
            color: const Color(0xFFC98AA8),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.bedtime_outlined,
            label: 'متوسط النوم',
            value: stats.avgSleep > 0
                ? '${stats.avgSleep.toStringAsFixed(1)}س'
                : '—',
            color: AppColors.sage,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
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
          Text(label,
              style: T.caption.copyWith(color: AppColors.textMuted)),
          const SizedBox(height: 4),
          Text(value,
              style: T.headline.copyWith(color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}

class _PainChart extends StatelessWidget {
  final InsightsData stats;
  const _PainChart({required this.stats});

  @override
  Widget build(BuildContext context) {
    final recent = stats.recentLogs;
    if (recent.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.nightElevated,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('الألم آخر ${recent.length} تسجيل', style: T.title),
          const SizedBox(height: 4),
          Text('0 = مفيش • 5 = شديد جداً',
              style: T.caption.copyWith(color: AppColors.textMuted)),
          const SizedBox(height: 20),
          SizedBox(
            height: 160,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: 5,
                minX: 0,
                maxX: (recent.length - 1).toDouble().clamp(1, 999),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 1,
                  getDrawingHorizontalLine: (_) =>
                      const FlLine(color: AppColors.outline, strokeWidth: 0.5),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      reservedSize: 24,
                      getTitlesWidget: (v, _) => Text(
                        v.toInt().toString(),
                        style: T.caption
                            .copyWith(color: AppColors.textMuted),
                      ),
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineTouchData: const LineTouchData(enabled: true),
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      for (int i = 0; i < recent.length; i++)
                        FlSpot(i.toDouble(), recent[i].pain.toDouble()),
                    ],
                    isCurved: true,
                    curveSmoothness: 0.3,
                    color: AppColors.coral,
                    barWidth: 3,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, _, __, ___) =>
                          FlDotCirclePainter(
                        radius: 4,
                        color: AppColors.coral,
                        strokeWidth: 2,
                        strokeColor: AppColors.night,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          AppColors.coral.withValues(alpha: 0.3),
                          AppColors.coral.withValues(alpha: 0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PatternsCard extends StatelessWidget {
  final InsightsData stats;
  const _PatternsCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final patterns = stats.patterns;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.nightElevated,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome,
                  color: AppColors.coral, size: 20),
              const SizedBox(width: 8),
              Text('الأنماط', style: T.title),
            ],
          ),
          const SizedBox(height: 16),
          if (patterns.isEmpty)
            Text(
              'سجلي كام يوم كمان عشان نبدأ نعرض أنماط جسمك.',
              style: T.body.copyWith(color: AppColors.textMuted),
            )
          else
            ...patterns.map(
              (p) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 7),
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.coral,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(p, style: T.body)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.nightElevated,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        children: [
          const Icon(Icons.insights, color: AppColors.textMuted, size: 48),
          const SizedBox(height: 16),
          Text('لسه مفيش بيانات كفاية',
              style: T.title, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(
            'سجلي كام يوم من حالتك عشان نعرض لك الأنماط والرؤى.',
            style: T.body.copyWith(color: AppColors.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}