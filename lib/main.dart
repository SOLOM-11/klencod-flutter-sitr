import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'calendar_screen.dart';
import 'data.dart';
import 'home.dart';
import 'insights.dart';
import 'lock.dart';
import 'onboarding.dart';
import 'settings.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ar', null);

  final prefs = await SharedPreferences.getInstance();
  const storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  final pin = await storage.read(key: 'pin');

  runApp(ProviderScope(
    overrides: [
      prefsProvider.overrideWithValue(prefs),
      hasPinProvider.overrideWith((ref) => pin != null && pin.isNotEmpty),
    ],
    child: const SitrApp(),
  ));
}

class SitrApp extends ConsumerStatefulWidget {
  const SitrApp({super.key});

  @override
  ConsumerState<SitrApp> createState() => _SitrAppState();
}

class _SitrAppState extends ConsumerState<SitrApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    final hasProfile = ref.read(profileProvider) != null;
    final hasPin = ref.read(hasPinProvider);
    final initial = !hasProfile
        ? '/onboarding'
        : (hasPin ? '/lock' : '/home');

    _router = GoRouter(
      initialLocation: initial,
      routes: [
        GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
        GoRoute(path: '/lock', builder: (_, __) => const LockScreen()),
        GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
        GoRoute(path: '/calendar', builder: (_, __) => const CalendarScreen()),
        GoRoute(path: '/insights', builder: (_, __) => const InsightsScreen()),
        GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Sitr',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      darkTheme: buildTheme(),
      themeMode: ThemeMode.dark,
      routerConfig: _router,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}