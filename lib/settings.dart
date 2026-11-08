import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'data.dart';
import 'lock.dart';
import 'theme.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool? _bioAvailable;
  bool? _bioEnabled;

  @override
  void initState() {
    super.initState();
    _loadSecurity();
  }

  Future<void> _loadSecurity() async {
    final repo = ref.read(lockRepoProvider);
    final available = await repo.canUseBiometrics();
    final enabled = await repo.getBioEnabled();
    if (!mounted) return;
    setState(() {
      _bioAvailable = available;
      _bioEnabled = enabled;
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    if (profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final hasPin = ref.watch(hasPinProvider);
    final df = DateFormat('d MMMM yyyy', 'ar');

    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _SectionTitle('دورتك'),
              _Card(children: [
                _Tile(
                  icon: Icons.water_drop_outlined,
                  label: 'طول الدورة',
                  value: '${profile.cycleLength} يوم',
                  onTap: _editProfile,
                ),
                const _Divider(),
                _Tile(
                  icon: Icons.event_outlined,
                  label: 'طول النزيف',
                  value: '${profile.periodLength} أيام',
                  onTap: _editProfile,
                ),
                const _Divider(),
                _Tile(
                  icon: Icons.calendar_today_outlined,
                  label: 'آخر دورة',
                  value: df.format(profile.lastPeriodStart),
                  onTap: _editProfile,
                ),
              ]),
              const SizedBox(height: 20),
              const _SectionTitle('الأمان'),
              _Card(children: [
                if (!hasPin)
                  _Tile(
                    icon: Icons.lock_open,
                    label: 'تفعيل القفل',
                    value: 'غير مفعّل',
                    onTap: _enableLock,
                  )
                else ...[
                  const _Tile(
                    icon: Icons.lock,
                    label: 'القفل',
                    value: 'مفعّل',
                    valueColor: AppColors.coral,
                  ),
                  if (_bioAvailable == true) ...[
                    const _Divider(),
                    SwitchListTile(
                      value: _bioEnabled ?? false,
                      onChanged:
                          _bioEnabled == null ? null : (_) => _toggleBio(),
                      title: Text('فتح بالبصمة', style: T.title),
                      subtitle: Text(
                        _bioEnabled == true ? 'مفعّلة' : 'مش مفعّلة',
                        style:
                            T.caption.copyWith(color: AppColors.textMuted),
                      ),
                      secondary: const Icon(Icons.fingerprint,
                          color: AppColors.sage, size: 24),
                      activeColor: AppColors.coral,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                    ),
                  ],
                  const _Divider(),
                  _Tile(
                    icon: Icons.lock_open,
                    label: 'إزالة القفل',
                    value: '',
                    danger: true,
                    onTap: _removeLock,
                  ),
                ],
              ]),
              const SizedBox(height: 20),
              const _SectionTitle('بياناتي'),
              _Card(children: [
                _Tile(
                  icon: Icons.delete_outline,
                  label: 'مسح كل البيانات',
                  value: '',
                  danger: true,
                  onTap: _confirmReset,
                ),
              ]),
              const SizedBox(height: 20),
              const _SectionTitle('عن التطبيق'),
              _Card(children: [
                const _Tile(
                  icon: Icons.info_outline,
                  label: 'الإصدار',
                  value: '0.1.0',
                ),
                const _Divider(),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'سِتر مش بديل طبي. التوقعات تقريبية، ولو عندك أي قلق صحي استشيري دكتورة.',
                    style: T.body.copyWith(color: AppColors.textMuted),
                  ),
                ),
              ]),
              const SizedBox(height: 20),
              Center(
                child: Text('Sitr © 2026',
                    style: T.caption.copyWith(color: AppColors.textMuted)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editProfile() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _EditProfileSheet(),
    );
  }

  Future<void> _enableLock() async {
    final ok = await PinSetupSheet.show(context);
    if (ok == true) {
      await _loadSecurity();
    }
  }

  Future<void> _toggleBio() async {
    final repo = ref.read(lockRepoProvider);
    final messenger = ScaffoldMessenger.of(context);
    if (_bioEnabled == true) {
      await repo.setBioEnabled(false);
      if (!mounted) return;
      setState(() => _bioEnabled = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('تم إلغاء البصمة')),
      );
      return;
    }
    final ok = await repo.authenticateBiometric();
    if (!mounted) return;
    if (!ok) {
      messenger.showSnackBar(
        const SnackBar(content: Text('البصمة اتلغت')),
      );
      return;
    }
    await repo.setBioEnabled(true);
    if (!mounted) return;
    setState(() => _bioEnabled = true);
    messenger.showSnackBar(
      const SnackBar(content: Text('تم تفعيل البصمة ✨')),
    );
  }

  Future<void> _removeLock() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.nightElevated,
        title: const Text('إزالة القفل؟', style: T.title),
        content: Text(
          'هيتشال الـ PIN والبيانات هتفضل زي ما هي.',
          style: T.body.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.coral),
            child: const Text('إزالة'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;

    final repo = ref.read(lockRepoProvider);
    final messenger = ScaffoldMessenger.of(context);
    await repo.clearPin();
    await repo.setBioEnabled(false);
    if (!mounted) return;
    ref.read(hasPinProvider.notifier).state = false;
    setState(() => _bioEnabled = false);
    messenger.showSnackBar(
      const SnackBar(content: Text('تم إلغاء القفل')),
    );
  }

  Future<void> _confirmReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.nightElevated,
        title: const Text('مسح كل البيانات؟', style: T.title),
        content: Text(
          'هيتم مسح بروفايلك وكل التسجيلات. القفل هيفضل زي ما هو.',
          style: T.body.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.coral),
            child: const Text('مسح'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;

    await ref.read(profileProvider.notifier).clear();
    await ref.read(logsProvider.notifier).clearAll();
    if (!mounted) return;
    context.go('/onboarding');
  }
}

// ---------------- Edit profile sheet ----------------

class _EditProfileSheet extends ConsumerStatefulWidget {
  const _EditProfileSheet();

  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  late DateTime _lastPeriod;
  late int _cycleLength;
  late int _periodLength;

  @override
  void initState() {
    super.initState();
    final p = ref.read(profileProvider)!;
    _lastPeriod = p.lastPeriodStart;
    _cycleLength = p.cycleLength;
    _periodLength = p.periodLength;
  }

  Future<void> _save() async {
    final p = ref.read(profileProvider)!;
    await ref.read(profileProvider.notifier).save(UserProfile(
          lastPeriodStart: _lastPeriod,
          cycleLength: _cycleLength,
          periodLength: _periodLength,
          goal: p.goal,
        ));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('EEEE، d MMMM yyyy', 'ar');
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.nightElevated,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
              const Text('تعديل بيانات الدورة', style: T.headline),
              const SizedBox(height: 20),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _lastPeriod,
                    firstDate:
                        DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setState(() => _lastPeriod = picked);
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.night,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.outline),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined,
                          color: AppColors.coral),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          'آخر دورة: ${df.format(_lastPeriod)}',
                          style: T.body,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _valRow('طول الدورة', '$_cycleLength يوم'),
              Slider(
                value: _cycleLength.toDouble(),
                min: 18,
                max: 45,
                divisions: 27,
                onChanged: (v) => setState(() => _cycleLength = v.round()),
              ),
              const SizedBox(height: 12),
              _valRow('طول النزيف', '$_periodLength أيام'),
              Slider(
                value: _periodLength.toDouble(),
                min: 1,
                max: 12,
                divisions: 11,
                onChanged: (v) => setState(() => _periodLength = v.round()),
              ),
              const SizedBox(height: 24),
              FilledButton(onPressed: _save, child: const Text('حفظ')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _valRow(String l, String v) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(l, style: T.title),
          Text(v, style: T.title.copyWith(color: AppColors.coral)),
        ],
      );
}

// ---------------- shared widgets ----------------

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
        child: Text(text,
            style: T.caption.copyWith(
                color: AppColors.textMuted, letterSpacing: 1)),
      );
}

class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card({required this.children});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: AppColors.nightElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.outline),
        ),
        child: Column(children: children),
      );
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  final bool danger;
  final Color? valueColor;

  const _Tile({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
    this.danger = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.coral : AppColors.textPrimary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 14),
            Expanded(child: Text(label, style: T.title.copyWith(color: color))),
            if (value.isNotEmpty)
              Text(
                value,
                style: T.body.copyWith(color: valueColor ?? AppColors.textSecondary),
              ),
            if (onTap != null) ...[
              const SizedBox(width: 6),
              const Icon(Icons.chevron_left,
                  color: AppColors.textMuted, size: 20),
            ],
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) => Container(
        height: 1,
        color: AppColors.outline,
        margin: const EdgeInsets.symmetric(horizontal: 16),
      );
}