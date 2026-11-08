import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'data.dart';
import 'theme.dart';

class QuickLogSheet extends ConsumerStatefulWidget {
  final DateTime date;
  const QuickLogSheet({super.key, required this.date});

  static Future<void> show(BuildContext context, {DateTime? date}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => QuickLogSheet(date: date ?? DateTime.now()),
    );
  }

  @override
  ConsumerState<QuickLogSheet> createState() => _QuickLogSheetState();
}

class _QuickLogSheetState extends ConsumerState<QuickLogSheet> {
  late int _bleeding;
  late Set<String> _moods;
  late int _pain;
  late double _sleepHours;
  late TextEditingController _notes;

  @override
  void initState() {
    super.initState();
    final existing = ref.read(logsProvider.notifier).forDate(widget.date);
    _bleeding = existing?.bleeding ?? 0;
    _moods = {...(existing?.moods ?? const <String>{})};
    _pain = existing?.pain ?? 0;
    _sleepHours = existing?.sleepHours ?? 8;
    _notes = TextEditingController(text: existing?.notes ?? '');
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final log = DailyLog(
      date: widget.date,
      bleeding: _bleeding,
      moods: _moods,
      pain: _pain,
      sleepHours: _sleepHours,
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    );
    await ref.read(logsProvider.notifier).save(log);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final dateLabel = DateFormat('EEEE، d MMMM yyyy', 'ar').format(widget.date);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.nightElevated,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text('إزاي حاسة النهاردة؟', style: T.headline),
              const SizedBox(height: 4),
              Text(dateLabel,
                  style: T.body.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 24),
              const _SectionTitle('النزيف'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _pill('بدون',
                      selected: _bleeding == 0,
                      onTap: () => setState(() => _bleeding = 0)),
                  _pill('خفيف',
                      selected: _bleeding == 1,
                      onTap: () => setState(() => _bleeding = 1)),
                  _pill('متوسط',
                      selected: _bleeding == 2,
                      onTap: () => setState(() => _bleeding = 2)),
                  _pill('غزير',
                      selected: _bleeding == 3,
                      onTap: () => setState(() => _bleeding = 3)),
                ],
              ),
              const SizedBox(height: 22),
              const _SectionTitle('المزاج'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _moodPill('هادية', '🌿'),
                  _moodPill('سعيدة', '☀️'),
                  _moodPill('متوترة', '⚡'),
                  _moodPill('حزينة', '🌧️'),
                  _moodPill('متعبة', '🌙'),
                  _moodPill('قلقانة', '💭'),
                ],
              ),
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const _SectionTitle('الألم'),
                  Text(painLabel(_pain),
                      style: T.caption.copyWith(color: AppColors.coral)),
                ],
              ),
              Slider(
                value: _pain.toDouble(),
                min: 0,
                max: 5,
                divisions: 5,
                onChanged: (v) => setState(() => _pain = v.round()),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const _SectionTitle('ساعات النوم'),
                  Text('${_sleepHours.toStringAsFixed(1)} س',
                      style: T.caption.copyWith(color: AppColors.coral)),
                ],
              ),
              Slider(
                value: _sleepHours,
                min: 0,
                max: 12,
                divisions: 24,
                onChanged: (v) => setState(() => _sleepHours = v),
              ),
              const SizedBox(height: 8),
              const _SectionTitle('ملاحظات'),
              const SizedBox(height: 10),
              TextField(
                controller: _notes,
                minLines: 2,
                maxLines: 4,
                style: T.body.copyWith(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'أي حاجة تحبي تسجليها...',
                  hintStyle: T.body.copyWith(color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.night,
                  contentPadding: const EdgeInsets.all(14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppColors.outline),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppColors.outline),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppColors.coral),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(onPressed: _save, child: const Text('حفظ')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pill(String label,
      {required bool selected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.coral : AppColors.night,
          borderRadius: BorderRadius.circular(30),
          border:
              Border.all(color: selected ? AppColors.coral : AppColors.outline),
        ),
        child: Text(
          label,
          style: T.body.copyWith(
            color: selected ? AppColors.night : AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _moodPill(String label, String emoji) {
    final selected = _moods.contains(label);
    return GestureDetector(
      onTap: () => setState(() {
        if (selected) {
          _moods.remove(label);
        } else {
          _moods.add(label);
        }
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.plum : AppColors.night,
          borderRadius: BorderRadius.circular(30),
          border:
              Border.all(color: selected ? AppColors.coral : AppColors.outline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Text(
              label,
              style: T.body.copyWith(
                color: AppColors.textPrimary,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) =>
      Text(text, style: T.title.copyWith(fontSize: 15));
}