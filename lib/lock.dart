import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';

import 'data.dart';
import 'theme.dart';

final secureStorageProvider = Provider<FlutterSecureStorage>(
  (_) => const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  ),
);

final hasPinProvider = StateProvider<bool>((_) => false);

class LockRepo {
  LockRepo(this._storage, this._auth);
  final FlutterSecureStorage _storage;
  final LocalAuthentication _auth;
  static const _pinKey = 'pin';
  static const _bioKey = 'bio_enabled';

  Future<String?> getPin() => _storage.read(key: _pinKey);
  Future<void> setPin(String pin) => _storage.write(key: _pinKey, value: pin);
  Future<void> clearPin() => _storage.delete(key: _pinKey);

  Future<bool> getBioEnabled() async =>
      (await _storage.read(key: _bioKey)) == '1';
  Future<void> setBioEnabled(bool v) =>
      _storage.write(key: _bioKey, value: v ? '1' : '0');

  Future<bool> canUseBiometrics() async {
    try {
      return await _auth.canCheckBiometrics && await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticateBiometric() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'افتحي سِتر',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}

final lockRepoProvider = Provider<LockRepo>((ref) =>
    LockRepo(ref.watch(secureStorageProvider), LocalAuthentication()));

// ---------------- Lock Screen ----------------

class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  String _pin = '';
  String? _error;
  bool _bioTried = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryBiometric());
  }

  void _goAfterUnlock() {
    final hasProfile = ref.read(profileProvider) != null;
    context.go(hasProfile ? '/home' : '/onboarding');
  }

  Future<void> _tryBiometric() async {
    if (_bioTried) return;
    _bioTried = true;
    final repo = ref.read(lockRepoProvider);
    if (!await repo.getBioEnabled()) return;
    if (!await repo.canUseBiometrics()) return;
    final ok = await repo.authenticateBiometric();
    if (!mounted) return;
    if (ok) _goAfterUnlock();
  }

  Future<void> _checkPin(String pin) async {
    final stored = await ref.read(lockRepoProvider).getPin();
    if (!mounted) return;
    if (pin == stored) {
      _goAfterUnlock();
    } else {
      setState(() {
        _error = 'PIN غلط، جربي تاني';
        _pin = '';
      });
    }
  }

  void _onDigit(String d) {
    if (_pin.length >= 4) return;
    setState(() {
      _pin += d;
      _error = null;
    });
    if (_pin.length == 4) _checkPin(_pin);
  }

  void _onBackspace() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _biometricTap() async {
    final repo = ref.read(lockRepoProvider);
    final enabled = await repo.getBioEnabled();
    if (!mounted) return;
    if (!enabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('البصمة مش مفعلة. استخدمي الـ PIN أو فعّليها من الإعدادات.'),
        ),
      );
      return;
    }
    if (!await repo.canUseBiometrics()) return;
    final ok = await repo.authenticateBiometric();
    if (!mounted) return;
    if (ok) _goAfterUnlock();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient:
                    LinearGradient(colors: [AppColors.coral, AppColors.plum]),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.lock_outline,
                  color: AppColors.cream, size: 28),
            ),
            const SizedBox(height: 20),
            const Text('سِتر', style: T.headline),
            const SizedBox(height: 6),
            Text('أدخلي الـ PIN',
                style: T.body.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 24),
            _PinDots(length: 4, filled: _pin.length, error: _error != null),
            const SizedBox(height: 8),
            SizedBox(
              height: 20,
              child: _error != null
                  ? Text(_error!,
                      style: T.caption.copyWith(color: AppColors.coral))
                  : const SizedBox.shrink(),
            ),
            const Spacer(),
            _PinKeypad(
              onDigit: _onDigit,
              onBackspace: _onBackspace,
              onBiometric: _biometricTap,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ---------------- PIN setup sheet ----------------

class PinSetupSheet extends ConsumerStatefulWidget {
  const PinSetupSheet({super.key});

  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const PinSetupSheet(),
    );
  }

  @override
  ConsumerState<PinSetupSheet> createState() => _PinSetupSheetState();
}

class _PinSetupSheetState extends ConsumerState<PinSetupSheet> {
  String _step = 'enter';
  String _first = '';
  String _pin = '';
  String? _error;

  void _onDigit(String d) {
    if (_pin.length >= 4) return;
    setState(() {
      _pin += d;
      _error = null;
    });
    if (_pin.length == 4) _handleComplete();
  }

  void _onBackspace() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _handleComplete() async {
    if (_step == 'enter') {
      setState(() {
        _first = _pin;
        _pin = '';
        _step = 'confirm';
      });
      return;
    }

    if (_pin != _first) {
      setState(() {
        _error = 'الـ PIN مش متطابق، جربي تاني';
        _pin = '';
        _first = '';
        _step = 'enter';
      });
      return;
    }

    await ref.read(lockRepoProvider).setPin(_pin);
    if (!mounted) return;
    ref.read(hasPinProvider.notifier).state = true;

    await _askBiometrics();

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Future<void> _askBiometrics() async {
    final repo = ref.read(lockRepoProvider);
    final available = await repo.canUseBiometrics();
    if (!mounted) return;

    if (!available) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حفظ الـ PIN. البصمة مش متاحة على الجهاز ده.'),
        ),
      );
      return;
    }

    final enable = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.nightElevated,
        title: const Text('تفعيل البصمة؟', style: T.title),
        content: Text(
          'تقدري تفتحي سِتر ببصمة إيدك بدل الـ PIN.',
          style: T.body.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('مش دلوقتي'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.coral),
            child: const Text('تفعيل'),
          ),
        ],
      ),
    );

    if (enable != true) return;
    if (!mounted) return;

    final ok = await repo.authenticateBiometric();
    if (!mounted) return;

    if (ok) {
      await repo.setBioEnabled(true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تفعيل البصمة ✨')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('البصمة اتلغت، الـ PIN شغال.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(_step == 'enter' ? 'اختاري PIN' : 'أكدي الـ PIN',
                  style: T.headline),
              const SizedBox(height: 6),
              Text(
                _error ??
                    (_step == 'enter'
                        ? '4 أرقام لحماية بياناتك'
                        : 'أدخلي نفس الأرقام تاني'),
                style: T.body.copyWith(
                    color: _error != null
                        ? AppColors.coral
                        : AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              _PinDots(length: 4, filled: _pin.length, error: _error != null),
              const SizedBox(height: 24),
              _PinKeypad(
                onDigit: _onDigit,
                onBackspace: _onBackspace,
                onBiometric: () {},
                keySize: 62,
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('إلغاء'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------- shared widgets ----------------

class _PinDots extends StatelessWidget {
  final int length;
  final int filled;
  final bool error;
  const _PinDots({
    required this.length,
    required this.filled,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(length, (i) {
        final on = i < filled;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 8),
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: on
                ? (error ? AppColors.coral : AppColors.cream)
                : Colors.transparent,
            border: Border.all(
              color: error ? AppColors.coral : AppColors.outline,
              width: 1.5,
            ),
          ),
        );
      }),
    );
  }
}

class _PinKeypad extends StatelessWidget {
  final void Function(String) onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onBiometric;
  final double keySize;

  const _PinKeypad({
    required this.onDigit,
    required this.onBackspace,
    required this.onBiometric,
    this.keySize = 80,
  });

  @override
  Widget build(BuildContext context) {
    Widget key(String label, {VoidCallback? onTap, Widget? child}) {
      return SizedBox(
        width: keySize,
        height: keySize,
        child: InkWell(
          onTap: onTap ?? () => onDigit(label),
          borderRadius: BorderRadius.circular(keySize / 2),
          child: Center(
            child: child ??
                Text(label,
                    style: T.headline.copyWith(fontSize: keySize / 3.1)),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          for (final row in [
            ['1', '2', '3'],
            ['4', '5', '6'],
            ['7', '8', '9'],
          ])
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: row.map((d) => key(d)).toList(),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              key(
                '',
                onTap: onBiometric,
                child: Icon(Icons.fingerprint,
                    color: AppColors.sage, size: keySize * 0.4),
              ),
              key('0'),
              key(
                '',
                onTap: onBackspace,
                child: Icon(Icons.backspace_outlined,
                    color: AppColors.textSecondary, size: keySize * 0.32),
              ),
            ],
          ),
        ],
      ),
    );
  }
}