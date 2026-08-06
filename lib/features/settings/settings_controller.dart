import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/tables/tables.dart';
import '../today/providers.dart';

/// §4.5 / §6.7 설정 값 모델 (기본값 포함)
class UnwindSettings {
  final bool nightReminderEnabled;
  final String nightReminderTime; // 'HH:mm', 기본 22:00
  final bool billNotificationEnabled;
  final bool soundEnabled;
  final bool hapticsEnabled;
  final int dayStartHour; // 기본 6
  final bool onboardingCompleted;

  const UnwindSettings({
    this.nightReminderEnabled = true,
    this.nightReminderTime = '22:00',
    this.billNotificationEnabled = true,
    this.soundEnabled = true,
    this.hapticsEnabled = true,
    this.dayStartHour = 6,
    this.onboardingCompleted = false,
  });

  UnwindSettings copyWith({
    bool? nightReminderEnabled,
    String? nightReminderTime,
    bool? billNotificationEnabled,
    bool? soundEnabled,
    bool? hapticsEnabled,
    int? dayStartHour,
    bool? onboardingCompleted,
  }) =>
      UnwindSettings(
        nightReminderEnabled: nightReminderEnabled ?? this.nightReminderEnabled,
        nightReminderTime: nightReminderTime ?? this.nightReminderTime,
        billNotificationEnabled:
            billNotificationEnabled ?? this.billNotificationEnabled,
        soundEnabled: soundEnabled ?? this.soundEnabled,
        hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
        dayStartHour: dayStartHour ?? this.dayStartHour,
        onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      );

  (int, int) get reminderHourMinute {
    final parts = nightReminderTime.split(':');
    return (
      int.tryParse(parts[0]) ?? 22,
      parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0
    );
  }
}

/// 설정 컨트롤러 — DB(settings 키/값)와 동기화
final settingsControllerProvider =
    AsyncNotifierProvider<SettingsController, UnwindSettings>(
        SettingsController.new);

class SettingsController extends AsyncNotifier<UnwindSettings> {
  @override
  Future<UnwindSettings> build() async {
    final dao = ref.watch(databaseProvider).settingsDao;
    return UnwindSettings(
      nightReminderEnabled: await dao
          .getBool(SettingKeys.nightReminderEnabled, fallback: true),
      nightReminderTime:
          await dao.getValue(SettingKeys.nightReminderTime) ?? '22:00',
      billNotificationEnabled: await dao
          .getBool(SettingKeys.billNotificationEnabled, fallback: true),
      soundEnabled:
          await dao.getBool(SettingKeys.soundEnabled, fallback: true),
      hapticsEnabled:
          await dao.getBool(SettingKeys.hapticsEnabled, fallback: true),
      dayStartHour:
          await dao.getInt(SettingKeys.dayStartHour, fallback: 6),
      onboardingCompleted: await dao
          .getBool(SettingKeys.onboardingCompleted, fallback: false),
    );
  }

  Future<void> _set(String key, String value,
      UnwindSettings Function(UnwindSettings) update) async {
    final dao = ref.read(databaseProvider).settingsDao;
    await dao.setValue(key, value);
    final current = state.value ?? const UnwindSettings();
    state = AsyncData(update(current));
  }

  Future<void> setNightReminderEnabled(bool v) => _set(
      SettingKeys.nightReminderEnabled,
      '$v',
      (s) => s.copyWith(nightReminderEnabled: v));

  Future<void> setNightReminderTime(String hhmm) => _set(
      SettingKeys.nightReminderTime,
      hhmm,
      (s) => s.copyWith(nightReminderTime: hhmm));

  Future<void> setBillNotificationEnabled(bool v) => _set(
      SettingKeys.billNotificationEnabled,
      '$v',
      (s) => s.copyWith(billNotificationEnabled: v));

  Future<void> setSoundEnabled(bool v) => _set(
      SettingKeys.soundEnabled, '$v', (s) => s.copyWith(soundEnabled: v));

  Future<void> setHapticsEnabled(bool v) => _set(SettingKeys.hapticsEnabled,
      '$v', (s) => s.copyWith(hapticsEnabled: v));

  Future<void> setDayStartHour(int hour) => _set(SettingKeys.dayStartHour,
      '$hour', (s) => s.copyWith(dayStartHour: hour));

  Future<void> setOnboardingCompleted() => _set(
      SettingKeys.onboardingCompleted,
      'true',
      (s) => s.copyWith(onboardingCompleted: true));

  /// §6.7 데이터 초기화 — 할 일·기록·반복·청구서 전부 삭제 (설정은 유지)
  Future<void> resetAllData() async {
    final db = ref.read(databaseProvider);
    await db.transaction(() async {
      await db.delete(db.todos).go();
      await db.delete(db.days).go();
      await db.delete(db.recurrences).go();
      await db.delete(db.weeklyBills).go();
    });
  }
}
