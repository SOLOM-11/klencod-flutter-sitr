import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final prefsProvider = Provider<SharedPreferences>(
  (_) => throw UnimplementedError('overridden in main'),
);

class UserProfile {
  final DateTime lastPeriodStart;
  final int cycleLength;
  final int periodLength;
  final String goal;

  const UserProfile({
    required this.lastPeriodStart,
    required this.cycleLength,
    required this.periodLength,
    required this.goal,
  });

  Map<String, dynamic> toJson() => {
        'lastPeriodStart': lastPeriodStart.toIso8601String(),
        'cycleLength': cycleLength,
        'periodLength': periodLength,
        'goal': goal,
      };

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
        lastPeriodStart: DateTime.parse(j['lastPeriodStart'] as String),
        cycleLength: j['cycleLength'] as int,
        periodLength: j['periodLength'] as int,
        goal: j['goal'] as String,
      );
}

class ProfileRepository {
  ProfileRepository(this._prefs);
  final SharedPreferences _prefs;
  static const _key = 'profile';

  UserProfile? load() {
    final s = _prefs.getString(_key);
    if (s == null) return null;
    return UserProfile.fromJson(jsonDecode(s) as Map<String, dynamic>);
  }

  Future<void> save(UserProfile p) =>
      _prefs.setString(_key, jsonEncode(p.toJson()));

  Future<void> clear() => _prefs.remove(_key);
}

final profileRepoProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(ref.watch(prefsProvider)),
);

class ProfileNotifier extends StateNotifier<UserProfile?> {
  ProfileNotifier(this._repo) : super(_repo.load());
  final ProfileRepository _repo;

  Future<void> save(UserProfile p) async {
    await _repo.save(p);
    state = p;
  }

  Future<void> clear() async {
    await _repo.clear();
    state = null;
  }
}

final profileProvider = StateNotifierProvider<ProfileNotifier, UserProfile?>(
  (ref) => ProfileNotifier(ref.watch(profileRepoProvider)),
);

class CyclePrediction {
  final int dayInCycle;
  final int daysUntilNextPeriod;
  final DateTime nextPeriodStart;
  final DateTime ovulationDay;
  final String phase;

  const CyclePrediction({
    required this.dayInCycle,
    required this.daysUntilNextPeriod,
    required this.nextPeriodStart,
    required this.ovulationDay,
    required this.phase,
  });

  factory CyclePrediction.from(UserProfile p, {DateTime? now}) {
    final today = DateUtils.dateOnly(now ?? DateTime.now());
    final start = DateUtils.dateOnly(p.lastPeriodStart);
    final diff = today.difference(start).inDays;

    final day = (diff % p.cycleLength) + 1;
    final cyclesPassed = (diff ~/ p.cycleLength) + 1;
    final nextStart = start.add(Duration(days: cyclesPassed * p.cycleLength));
    final daysUntil = nextStart.difference(today).inDays;
    final ovulation = nextStart.subtract(const Duration(days: 14));
    final fertileStart = ovulation.subtract(const Duration(days: 5));
    final fertileEnd = ovulation.add(const Duration(days: 1));

    final String phase;
    if (day <= p.periodLength) {
      phase = 'menstrual';
    } else if (!today.isBefore(fertileStart) && !today.isAfter(fertileEnd)) {
      final d = today.difference(ovulation).inDays.abs();
      phase = d <= 1 ? 'ovulation' : 'fertile';
    } else if (today.isBefore(fertileStart)) {
      phase = 'follicular';
    } else {
      phase = 'luteal';
    }

    return CyclePrediction(
      dayInCycle: day,
      daysUntilNextPeriod: daysUntil,
      nextPeriodStart: nextStart,
      ovulationDay: ovulation,
      phase: phase,
    );
  }

  double get cycleProgress => dayInCycle / (dayInCycle + daysUntilNextPeriod);
}

class CycleMap {
  final UserProfile profile;
  CycleMap(this.profile);

  int _dayInCycle(DateTime date) {
    final start = DateUtils.dateOnly(profile.lastPeriodStart);
    final d = DateUtils.dateOnly(date);
    final diff = d.difference(start).inDays;
    if (diff < 0) return -1;
    return (diff % profile.cycleLength) + 1;
  }

  int get _ovulationDay => profile.cycleLength - 14 + 1;

  bool isPredictedPeriod(DateTime date) {
    final day = _dayInCycle(date);
    if (day < 0) return false;
    return day <= profile.periodLength;
  }

  bool isOvulation(DateTime date) {
    final day = _dayInCycle(date);
    if (day < 0) return false;
    return (day - _ovulationDay).abs() <= 1;
  }

  bool isFertile(DateTime date) {
    final day = _dayInCycle(date);
    if (day < 0) return false;
    return day >= _ovulationDay - 5 && day <= _ovulationDay + 1;
  }

  String? phaseFor(DateTime date) {
    final day = _dayInCycle(date);
    if (day < 0) return null;
    if (day <= profile.periodLength) return 'period';
    if (isOvulation(date)) return 'ovulation';
    if (isFertile(date)) return 'fertile';
    if (day < _ovulationDay - 5) return 'follicular';
    return 'luteal';
  }
}

class DailyLog {
  final DateTime date;
  final int bleeding;
  final Set<String> moods;
  final int pain;
  final double sleepHours;
  final String? notes;

  const DailyLog({
    required this.date,
    this.bleeding = 0,
    this.moods = const {},
    this.pain = 0,
    this.sleepHours = 8,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'bleeding': bleeding,
        'moods': moods.toList(),
        'pain': pain,
        'sleepHours': sleepHours,
        'notes': notes,
      };

  factory DailyLog.fromJson(Map<String, dynamic> j) => DailyLog(
        date: DateTime.parse(j['date'] as String),
        bleeding: (j['bleeding'] as num?)?.toInt() ?? 0,
        moods: ((j['moods'] as List?) ?? const []).cast<String>().toSet(),
        pain: (j['pain'] as num?)?.toInt() ?? 0,
        sleepHours: (j['sleepHours'] as num?)?.toDouble() ?? 8,
        notes: j['notes'] as String?,
      );
}

String painLabel(int p) => switch (p) {
      0 => 'مفيش',
      1 => 'خفيف جداً',
      2 => 'خفيف',
      3 => 'متوسط',
      4 => 'شديد',
      5 => 'شديد جداً',
      _ => '',
    };

class LogsRepository {
  LogsRepository(this._prefs);
  final SharedPreferences _prefs;
  static const _key = 'logs';

  Map<String, DailyLog> loadAll() {
    final s = _prefs.getString(_key);
    if (s == null) return {};
    final m = jsonDecode(s) as Map<String, dynamic>;
    return m.map(
      (k, v) => MapEntry(k, DailyLog.fromJson(v as Map<String, dynamic>)),
    );
  }

  Future<void> saveAll(Map<String, DailyLog> logs) async {
    final m = logs.map((k, v) => MapEntry(k, v.toJson()));
    await _prefs.setString(_key, jsonEncode(m));
  }

  Future<void> clear() => _prefs.remove(_key);
}

final logsRepoProvider = Provider<LogsRepository>(
  (ref) => LogsRepository(ref.watch(prefsProvider)),
);

class LogsNotifier extends StateNotifier<Map<String, DailyLog>> {
  LogsNotifier(this._repo) : super(_repo.loadAll());
  final LogsRepository _repo;

  static String keyOf(DateTime d) => d.toIso8601String().split('T').first;

  DailyLog? forDate(DateTime d) => state[keyOf(d)];

  Future<void> save(DailyLog log) async {
    final k = keyOf(log.date);
    final next = {...state, k: log};
    await _repo.saveAll(next);
    state = next;
  }

  Future<void> remove(DateTime d) async {
    final k = keyOf(d);
    final next = {...state}..remove(k);
    await _repo.saveAll(next);
    state = next;
  }

  Future<void> clearAll() async {
    await _repo.clear();
    state = {};
  }
}

final logsProvider = StateNotifierProvider<LogsNotifier, Map<String, DailyLog>>(
  (ref) => LogsNotifier(ref.watch(logsRepoProvider)),
);