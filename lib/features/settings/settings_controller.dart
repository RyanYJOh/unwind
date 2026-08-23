import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/tables/tables.dart';
import '../today/providers.dart';

/// §4.5 / §6.7 설정 값 모델 (기본값 포함)
///
/// 세계관 통합 (2026-08-15): Todd에겐 기상시간과 취침시간이 있다.
/// - [wakeHour] 기본 05시 — 하루의 경계(롤오버)이자 Todd의 낮 시작.
///   (구 dayStartHour를 흡수 — 저장된 옛 키는 읽기 폴백으로 존중한다)
/// - [bedtimeHour] 기본 22시 — 이 시각부터 Todd는 자야 한다. 불이 남아
///   있으면 못 자고, 취침 알림은 이 시각 30분 전에 발송한다 (구
///   nightReminderTime을 흡수 — 별도 리마인더 시각은 없다).
class UnwindSettings {
  final bool nightReminderEnabled;
  final bool billNotificationEnabled;
  final bool morningGreetingEnabled;
  final bool todoReminderEnabled;
  final bool hapticsEnabled;
  final int wakeHour; // 기본 5 — Todd
  final int bedtimeHour; // 기본 22 — Todd

  /// 온보딩에서 받은 유저 기상·취침. null = 기존 유저(키 없음) —
  /// 표시는 Todd 시각 +1h 폴백.
  final int? userWakeHour;
  final int? userBedtimeHour;
  final bool onboardingCompleted;

  /// 온보딩 직후, 전등 줄 코치마크를 아직 안 보여 줌
  final bool pullCordCoachAwaiting;

  /// 전등 줄 코치마크를 이미 보여 줌 (최초 1회)
  final bool pullCordCoachShown;

  /// Todd가 부르는 사용자 이름 (온보딩 2026-08-15). null = 안 알려줌.
  final String? userName;

  /// 앱 언어 — 기본 영어. 지원 언어는 l10n/*.arb 추가로 확장한다.
  final String languageCode;

  /// 방 조명의 색 (선택형 2026-08-22) — UnwindLightColor.name
  final String lightColor;

  /// Todd Plus (수익화 2026-08-22) — 조명 색·반복 무제한의 게이트
  final bool premiumEnabled;

  const UnwindSettings({
    this.nightReminderEnabled = true,
    this.billNotificationEnabled = true,
    this.morningGreetingEnabled = true,
    this.todoReminderEnabled = true,
    this.hapticsEnabled = true,
    this.wakeHour = 5,
    this.bedtimeHour = 22,
    this.userWakeHour,
    this.userBedtimeHour,
    this.onboardingCompleted = false,
    this.pullCordCoachAwaiting = false,
    this.pullCordCoachShown = false,
    this.userName,
    this.languageCode = 'en',
    this.lightColor = 'amber',
    this.premiumEnabled = false,
  });

  UnwindSettings copyWith({
    bool? nightReminderEnabled,
    bool? billNotificationEnabled,
    bool? morningGreetingEnabled,
    bool? todoReminderEnabled,
    bool? hapticsEnabled,
    int? wakeHour,
    int? bedtimeHour,
    int? userWakeHour,
    int? userBedtimeHour,
    bool? onboardingCompleted,
    bool? pullCordCoachAwaiting,
    bool? pullCordCoachShown,
    String? userName,
    String? languageCode,
    String? lightColor,
    bool? premiumEnabled,
  }) => UnwindSettings(
    nightReminderEnabled: nightReminderEnabled ?? this.nightReminderEnabled,
    billNotificationEnabled:
        billNotificationEnabled ?? this.billNotificationEnabled,
    morningGreetingEnabled:
        morningGreetingEnabled ?? this.morningGreetingEnabled,
    todoReminderEnabled: todoReminderEnabled ?? this.todoReminderEnabled,
    hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
    wakeHour: wakeHour ?? this.wakeHour,
    bedtimeHour: bedtimeHour ?? this.bedtimeHour,
    userWakeHour: userWakeHour ?? this.userWakeHour,
    userBedtimeHour: userBedtimeHour ?? this.userBedtimeHour,
    onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
    pullCordCoachAwaiting: pullCordCoachAwaiting ?? this.pullCordCoachAwaiting,
    pullCordCoachShown: pullCordCoachShown ?? this.pullCordCoachShown,
    userName: userName ?? this.userName,
    languageCode: languageCode ?? this.languageCode,
    lightColor: lightColor ?? this.lightColor,
    premiumEnabled: premiumEnabled ?? this.premiumEnabled,
  );

  /// 설정에 보여줄 유저 기상. 저장된 값이 없으면 Todd 기상 +1h.
  int get displayUserWakeHour => userWakeHour ?? (wakeHour + 1) % 24;

  /// 설정에 보여줄 유저 취침. 저장된 값이 없으면 Todd 취침 +1h.
  int get displayUserBedtimeHour => userBedtimeHour ?? (bedtimeHour + 1) % 24;
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
      morningGreetingEnabled: await dao.getBool(
        SettingKeys.morningGreetingEnabled,
        fallback: true,
      ),
      todoReminderEnabled: await dao.getBool(
        SettingKeys.todoReminderEnabled,
        fallback: true,
      ),
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
      userWakeHour: int.tryParse(
        await dao.getValue(SettingKeys.userWakeHour) ?? '',
      ),
      userBedtimeHour: int.tryParse(
        await dao.getValue(SettingKeys.userBedtimeHour) ?? '',
      ),
      onboardingCompleted: await dao.getBool(
        SettingKeys.onboardingCompleted,
        fallback: false,
      ),
      pullCordCoachAwaiting: await dao.getBool(
        SettingKeys.pullCordCoachAwaiting,
        fallback: false,
      ),
      pullCordCoachShown: await dao.getBool(
        SettingKeys.pullCordCoachShown,
        fallback: false,
      ),
      userName: await dao.getValue(SettingKeys.userName),
      languageCode: await dao.getValue(SettingKeys.languageCode) ?? 'en',
      lightColor: await dao.getValue(SettingKeys.lightColor) ?? 'amber',
      premiumEnabled: await dao.getBool(
        SettingKeys.premiumEnabled,
        fallback: false,
      ),
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

  Future<void> setMorningGreetingEnabled(bool v) => _set(
    SettingKeys.morningGreetingEnabled,
    '$v',
    (s) => s.copyWith(morningGreetingEnabled: v),
  );

  Future<void> setTodoReminderEnabled(bool v) => _set(
    SettingKeys.todoReminderEnabled,
    '$v',
    (s) => s.copyWith(todoReminderEnabled: v),
  );

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

  Future<void> setUserWakeHour(int hour) => _set(
    SettingKeys.userWakeHour,
    '$hour',
    (s) => s.copyWith(userWakeHour: hour),
  );

  Future<void> setUserBedtimeHour(int hour) => _set(
    SettingKeys.userBedtimeHour,
    '$hour',
    (s) => s.copyWith(userBedtimeHour: hour),
  );

  Future<void> setUserName(String name) =>
      _set(SettingKeys.userName, name, (s) => s.copyWith(userName: name));

  Future<void> setOnboardingCompleted() async {
    await _set(
      SettingKeys.onboardingCompleted,
      'true',
      (s) => s.copyWith(onboardingCompleted: true),
    );
    await _set(
      SettingKeys.pullCordCoachAwaiting,
      'true',
      (s) => s.copyWith(pullCordCoachAwaiting: true),
    );
  }

  Future<void> setPullCordCoachShown() async {
    await _set(
      SettingKeys.pullCordCoachShown,
      'true',
      (s) => s.copyWith(pullCordCoachShown: true),
    );
    await _set(
      SettingKeys.pullCordCoachAwaiting,
      'false',
      (s) => s.copyWith(pullCordCoachAwaiting: false),
    );
  }

  Future<void> setLanguageCode(String code) => _set(
    SettingKeys.languageCode,
    code,
    (s) => s.copyWith(languageCode: code),
  );

  /// 방 조명의 색 (선택형 2026-08-22) — 팔레트 적용은 UnwindApp이
  /// 설정을 watch하며 UnwindColors.setLightColor로 흘린다.
  Future<void> setLightColor(String name) => _set(
    SettingKeys.lightColor,
    name,
    (s) => s.copyWith(lightColor: name),
  );

  /// Todd Plus on/off. TODO(unwind): StoreKit 연동 시 구매·복원 흐름으로
  /// 대체 — 지금은 페이월 CTA와 dev 해제 버튼이 직접 부른다.
  Future<void> setPremiumEnabled(bool v) => _set(
    SettingKeys.premiumEnabled,
    '$v',
    (s) => s.copyWith(premiumEnabled: v),
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
