import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/tables/tables.dart';
import '../today/providers.dart';

/// §4.5 / §6.7 설정 값 모델 (기본값 포함)
///
/// 세계관 통합 (2026-08-15): Lumi에겐 기상시간과 취침시간이 있다.
/// - [wakeHour] 기본 05시 — 하루의 경계(롤오버)이자 Lumi의 낮 시작.
///   (구 dayStartHour를 흡수 — 저장된 옛 키는 읽기 폴백으로 존중한다)
/// - [bedtimeHour] 기본 22시 — 이 시각부터 Lumi는 자야 한다. 불이 남아
///   있으면 못 자고, 취침 알림도 이 시각에 발송한다 (구 nightReminderTime
///   을 흡수 — 별도 리마인더 시각은 없다).
class UnwindSettings {
  final bool nightReminderEnabled;
  final bool billNotificationEnabled;
  final bool soundEnabled;
  final bool hapticsEnabled;
  final int wakeHour; // 기본 5
  final int bedtimeHour; // 기본 22
  final bool onboardingCompleted;

  /// Lumi가 부르는 사용자 이름 (온보딩 2026-08-15). null = 안 알려줌.
  final String? userName;

  /// 앱 언어 — 기본 영어. 지원 언어는 l10n/*.arb 추가로 확장한다.
  final String languageCode;

  const UnwindSettings({
    this.nightReminderEnabled = true,
    this.billNotificationEnabled = true,
    this.soundEnabled = true,
    this.hapticsEnabled = true,
    this.wakeHour = 5,
    this.bedtimeHour = 22,
    this.onboardingCompleted = false,
    this.userName,
    this.languageCode = 'en',
  });

  UnwindSettings copyWith({
    bool? nightReminderEnabled,
    bool? billNotificationEnabled,
    bool? soundEnabled,
    bool? hapticsEnabled,
    int? wakeHour,
    int? bedtimeHour,
    bool? onboardingCompleted,
    String? userName,
    String? languageCode,
  }) => UnwindSettings(
    nightReminderEnabled: nightReminderEnabled ?? this.nightReminderEnabled,
    billNotificationEnabled:
        billNotificationEnabled ?? this.billNotificationEnabled,
    soundEnabled: soundEnabled ?? this.soundEnabled,
    hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
    wakeHour: wakeHour ?? this.wakeHour,
    bedtimeHour: bedtimeHour ?? this.bedtimeHour,
    onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
    userName: userName ?? this.userName,
    languageCode: languageCode ?? this.languageCode,
  );
}

/// 설정 컨트롤러 — DB(settings 키/값)와 동기화
final settingsControllerProvider =
    AsyncNotifierProvider<SettingsController, UnwindSettings>(
      SettingsController.new,
    );

class SettingsController extends AsyncNotifier<UnwindSettings> {
  @override
  Future<UnwindSettings> build() async {
    final dao = ref.watch(databaseProvider).settingsDao;
    return UnwindSettings(
      nightReminderEnabled: await dao.getBool(
        SettingKeys.nightReminderEnabled,
        fallback: true,
      ),
      billNotificationEnabled: await dao.getBool(
        SettingKeys.billNotificationEnabled,
        fallback: true,
      ),
      soundEnabled: await dao.getBool(SettingKeys.soundEnabled, fallback: true),
      hapticsEnabled: await dao.getBool(
        SettingKeys.hapticsEnabled,
        fallback: true,
      ),
      // 통합 이전에 dayStartHour를 바꿔 둔 사용자의 선택을 존중한다
      wakeHour: await dao.getInt(
        SettingKeys.wakeHour,
        fallback: await dao.getInt(SettingKeys.legacyDayStartHour, fallback: 5),
      ),
      bedtimeHour: await dao.getInt(SettingKeys.bedtimeHour, fallback: 22),
      onboardingCompleted: await dao.getBool(
        SettingKeys.onboardingCompleted,
        fallback: false,
      ),
      userName: await dao.getValue(SettingKeys.userName),
      languageCode: await dao.getValue(SettingKeys.languageCode) ?? 'en',
    );
  }

  Future<void> _set(
    String key,
    String value,
    UnwindSettings Function(UnwindSettings) update,
  ) async {
    final dao = ref.read(databaseProvider).settingsDao;
    await dao.setValue(key, value);
    final current = state.value ?? const UnwindSettings();
    state = AsyncData(update(current));
  }

  Future<void> setNightReminderEnabled(bool v) => _set(
    SettingKeys.nightReminderEnabled,
    '$v',
    (s) => s.copyWith(nightReminderEnabled: v),
  );

  Future<void> setBillNotificationEnabled(bool v) => _set(
    SettingKeys.billNotificationEnabled,
    '$v',
    (s) => s.copyWith(billNotificationEnabled: v),
  );

  Future<void> setSoundEnabled(bool v) =>
      _set(SettingKeys.soundEnabled, '$v', (s) => s.copyWith(soundEnabled: v));

  Future<void> setHapticsEnabled(bool v) => _set(
    SettingKeys.hapticsEnabled,
    '$v',
    (s) => s.copyWith(hapticsEnabled: v),
  );

  Future<void> setWakeHour(int hour) =>
      _set(SettingKeys.wakeHour, '$hour', (s) => s.copyWith(wakeHour: hour));

  Future<void> setBedtimeHour(int hour) => _set(
    SettingKeys.bedtimeHour,
    '$hour',
    (s) => s.copyWith(bedtimeHour: hour),
  );

  Future<void> setUserName(String name) =>
      _set(SettingKeys.userName, name, (s) => s.copyWith(userName: name));

  Future<void> setOnboardingCompleted() => _set(
    SettingKeys.onboardingCompleted,
    'true',
    (s) => s.copyWith(onboardingCompleted: true),
  );

  Future<void> setLanguageCode(String code) => _set(
    SettingKeys.languageCode,
    code,
    (s) => s.copyWith(languageCode: code),
  );

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

  /// 완전 초기화 (개발용) — 설정·온보딩 플래그까지 전부 삭제해 첫 실행
  /// 상태로 되돌린다. TODO(unwind): 배포 빌드에서는 이 기능과 설정 화면의
  /// 진입 버튼을 제거할 것.
  Future<void> fullResetForDev() async {
    final db = ref.read(databaseProvider);
    await db.transaction(() async {
      await db.delete(db.todos).go();
      await db.delete(db.days).go();
      await db.delete(db.recurrences).go();
      await db.delete(db.weeklyBills).go();
      await db.delete(db.settings).go();
    });
    ref.invalidateSelf();
  }
}
