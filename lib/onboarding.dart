import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'data.dart';
import 'theme.dart';

class OnboardingState {
  final int page;
  final DateTime? lastPeriodStart;
  final int cycleLength;
  final int periodLength;
  final String? goal;

  const OnboardingState({
    this.page = 0,
    this.lastPeriodStart,
    this.cycleLength = 28,
    this.periodLength = 5,
    this.goal,
  });

  OnboardingState copyWith({
    int? page,
    DateTime? lastPeriodStart,
    int? cycleLength,
    int? periodLength,
    String? goal,
  }) =>
      OnboardingState(
        page: page ?? this.page,
        lastPeriodStart: lastPeriodStart ?? this.lastPeriodStart,
        cycleLength: cycleLength ?? this.cycleLength,
        periodLength: periodLength ?? this.periodLength,
        goal: goal ?? this.goal,
      );

  bool get canContinue => switch (page) {
        0 => true,
        1 => lastPeriodStart != null,
        2 => cycleLength >= 18 && cycleLength <= 45 && periodLength >= 1 && periodLength <= 12,
        3 => goal != null,
        _ => true,
      };

  bool get isLastPage => page == 3;
}

class OnboardingController extends StateNotifier<OnboardingState> {
  OnboardingController() : super(const OnboardingState());
  void next() => state = state.copyWith(page: state.page + 1);
  void back() { if (state.page > 0) state = state.copyWith(page: state.page - 1); }
  void setLastPeriodStart(DateTime d) => state = state.copyWith(lastPeriodStart: d);
  void setCycleLength(int v) => state = state.copyWith(cycleLength: v);
  void setPeriodLength(int v) => state = state.copyWith(periodLength: v);
  void setGoal(String g) => state = state.copyWith(goal: g);
}

final onboardingProvider =
    StateNotifierProvider<OnboardingController, OnboardingState>(
  (_) => OnboardingController(),
);

class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingProvider);
    final c = ref.read(onboardingProvider.notifier);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 12),
              _Dots(total: 4, current: state.page),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  child: SizedBox.expand(
                    key: ValueKey(state.page),
                    child: switch (state.page) {
                      0 => const _Welcome(),
                      1 => const _LastPeriod(),
                      2 => const _Cycle(),
                      _ => const _Goal(),
                    },
                  ),
                ),
              ),
              FilledButton(
                onPressed: !state.canContinue
                    ? null
                    : () async {
                        if (state.isLastPage) {
                          final p = UserProfile(
                            lastPeriodStart: state.lastPeriodStart!,
                            cycleLength: state.cycleLength,
                            periodLength: state.periodLength,
                            goal: state.goal!,
                          );
                          await ref.read(profileProvider.notifier).save(p);
                          if (context.mounted) context.go('/home');
                        } else {
                          c.next();
                        }
                      },
                child: Text(state.isLastPage ? 'ابدئي' : 'متابعة'),
              ),
              if (state.page > 0)
                TextButton(onPressed: c.back, child: const Text('رجوع')),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  final int total, current;
  const _Dots({required this.total, required this.current});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(total, (i) {
          final active = i == current;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            height: 6,
            width: active ? 22 : 6,
            decoration: BoxDecoration(
              color: active ? AppColors.coral : AppColors.outline,
              borderRadius: BorderRadius.circular(3),
            ),
          );
        }),
      );
}

class _Welcome extends StatelessWidget {
  const _Welcome();

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(),
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [AppColors.coral, AppColors.plum]),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.lock_outline, color: AppColors.cream, size: 30),
          ),
          const SizedBox(height: 28),
          const Text('أهلاً بكِ في سِتر', style: T.display),
          const SizedBox(height: 12),
          Text(
            'إيقاعكِ الشهري، بصورة أهدى وأذكى. تتبعي دورتكِ، افهمي جسدكِ، وكل شيء في سِتر.',
            style: T.body.copyWith(color: AppColors.textSecondary),
          ),
          const Spacer(flex: 2),
        ],
      );
}

class _LastPeriod extends ConsumerWidget {
  const _LastPeriod();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingProvider);
    final c = ref.read(onboardingProvider.notifier);
    final df = DateFormat('EEEE، d MMMM yyyy', 'ar');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Spacer(),
        const Text('آخر دورة بدأت إمتى؟', style: T.headline),
        const SizedBox(height: 8),
        Text('ده هيساعدنا نتوقع دورتكِ وتبويضكِ بدقة.',
            style: T.body.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 32),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: state.lastPeriodStart ?? DateTime.now(),
              firstDate: DateTime.now().subtract(const Duration(days: 365)),
              lastDate: DateTime.now(),
            );
            if (picked != null) c.setLastPeriodStart(picked);
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.nightElevated,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.outline),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_outlined, color: AppColors.coral),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    state.lastPeriodStart == null
                        ? 'اختاري التاريخ'
                        : df.format(state.lastPeriodStart!),
                    style: T.title,
                  ),
                ),
              ],
            ),
          ),
        ),
        const Spacer(flex: 2),
      ],
    );
  }
}

class _Cycle extends ConsumerWidget {
  const _Cycle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingProvider);
    final c = ref.read(onboardingProvider.notifier);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          const Text('عن دورتكِ', style: T.headline),
          const SizedBox(height: 8),
          Text('لو مش متأكدة، سيبها على المتوسط، وتقدر تعدلها بعدين.',
              style: T.body.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 32),
          _ValueRow(label: 'طول الدورة', value: '${state.cycleLength} يوم'),
          Slider(
            value: state.cycleLength.toDouble(),
            min: 18, max: 45, divisions: 27,
            onChanged: (v) => c.setCycleLength(v.round()),
          ),
          const SizedBox(height: 20),
          _ValueRow(label: 'طول النزيف', value: '${state.periodLength} أيام'),
          Slider(
            value: state.periodLength.toDouble(),
            min: 1, max: 12, divisions: 11,
            onChanged: (v) => c.setPeriodLength(v.round()),
          ),
        ],
      ),
    );
  }
}

class _Goal extends ConsumerWidget {
  const _Goal();

  static const _goals = [
    ('track', 'أتابع دورتي', 'تسجيل بسيط + توقعات دقيقة'),
    ('conceive', 'أخطط للحمل', 'تركيز على نافذة الخصوبة'),
    ('avoid', 'أفهم جسدي', 'أنماط الأعراض والمزاج'),
    ('health', 'صحة عامة', 'متابعة الأعراض مع الوقت'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingProvider);
    final c = ref.read(onboardingProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Spacer(),
        const Text('إيه هدفكِ الأساسي؟', style: T.headline),
        const SizedBox(height: 8),
        Text('نقدر نخصص تجربتكِ على أساس اختيارك.',
            style: T.body.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 24),
        ..._goals.map((g) {
          final selected = state.goal == g.$1;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              onTap: () => c.setGoal(g.$1),
              borderRadius: BorderRadius.circular(16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: selected ? AppColors.plum : AppColors.nightElevated,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: selected ? AppColors.coral : AppColors.outline,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(g.$2, style: T.title),
                          const SizedBox(height: 2),
                          Text(g.$3,
                              style: T.caption.copyWith(color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                    if (selected)
                      const Icon(Icons.check_circle, color: AppColors.coral),
                  ],
                ),
              ),
            ),
          );
        }),
        const Spacer(flex: 2),
      ],
    );
  }
}

class _ValueRow extends StatelessWidget {
  final String label, value;
  const _ValueRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: T.title),
          Text(value, style: T.title.copyWith(color: AppColors.coral)),
        ],
      );
}