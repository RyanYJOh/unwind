import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/haptics/haptics.dart';
import '../../core/sound/sound_player.dart';
import '../../core/utils/dates.dart';
import '../../data/db/database.dart';
import '../../data/db/tables/tables.dart';
import '../../data/repositories/todo_repository.dart';
import '../../domain/services/brightness_engine.dart';
import '../../domain/services/day_rollover_service.dart';

/// DB — 앱 전역 단일 인스턴스 (§3.2 단일 진실 공급원)
final databaseProvider = Provider<UnwindDatabase>((ref) {
  final db = UnwindDatabase();
  ref.onDispose(db.close);
  return db;
});

final todoRepositoryProvider = Provider<TodoRepository>(
    (ref) => TodoRepository(ref.watch(databaseProvider)));

final hapticsProvider = Provider<UnwindHaptics>((ref) => UnwindHaptics());

final soundPlayerProvider = Provider<SoundPlayer>((ref) {
  final p = SoundPlayer();
  p.init();
  ref.onDispose(p.dispose);
  return p;
});

/// §4.5 dayStartHour — M1은 기본값 6 고정, 설정 화면(M4)에서 연결
final dayStartHourProvider = Provider<int>((ref) => 6);

/// 논리적 오늘의 dayKey. 롤오버 서비스가 갱신한다.
final todayKeyProvider = NotifierProvider<TodayKeyNotifier, String>(
    TodayKeyNotifier.new);

class TodayKeyNotifier extends Notifier<String> {
  DayRolloverService? _service;

  @override
  String build() {
    final dayStart = ref.watch(dayStartHourProvider);
    final service = DayRolloverService(
      db: ref.watch(databaseProvider),
      dayStartHour: dayStart,
      onRollover: (newKey) => state = newKey,
    );
    _service?.dispose();
    _service = service;
    service.start();
    ref.onDispose(service.dispose);
    return service.todayKey;
  }
}

/// 오늘의 할 일 스트림 — sortIndex 고정 정렬
final todayTodosProvider = StreamProvider<List<Todo>>((ref) {
  final repo = ref.watch(todoRepositoryProvider);
  return repo.watchTodos(ref.watch(todayKeyProvider));
});

/// 오늘의 days 행 (peakProgress / lightsOutAt)
final todayDayProvider = StreamProvider<Day?>((ref) {
  final repo = ref.watch(todoRepositoryProvider);
  return repo.watchDay(ref.watch(todayKeyProvider));
});

/// §3.2 조도 상태는 앱 전역에서 단 하나의 값 — 목표 t.
/// (표시용 보간·펄스·호흡은 화면 레이어에서 이 목표를 따라간다)
final brightnessProvider = Provider<double>((ref) {
  final todos = ref.watch(todayTodosProvider).value;
  final day = ref.watch(todayDayProvider).value;

  if (day?.lightsOutAt != null) return 1.0; // §5.3 당긴 후 고정
  if (todos == null) return BrightnessEngine.emptyRoomT; // 로딩 중
  final counted =
      todos.where((t) => t.status != TodoStatus.deferred).length;
  if (counted == 0) return BrightnessEngine.emptyRoomT; // §5.3 빈 방
  return (day?.peakProgress ?? 0.0).clamp(0.0, 1.0);
});

/// 전등 줄 활성 조건 (§6.4): 항목 있음 + 아직 안 당김
final pullCordEnabledProvider = Provider<bool>((ref) {
  final todos = ref.watch(todayTodosProvider).value ?? const [];
  final day = ref.watch(todayDayProvider).value;
  return todos.isNotEmpty && day?.lightsOutAt == null;
});

/// Lumi 취침 여부 (§6.1 FAB 동작 분기에도 사용)
final isAsleepProvider = Provider<bool>((ref) =>
    ref.watch(todayDayProvider).value?.lightsOutAt != null);

/// 입력 시트의 기본 날짜 (§6.1): 취침 후엔 내일
final composeDefaultDateProvider = Provider<String>((ref) {
  final todayKey = ref.watch(todayKeyProvider);
  if (!ref.watch(isAsleepProvider)) return todayKey;
  return dayKey(addDays(parseDayKey(todayKey), 1));
});
