/// 날짜 유틸 — DB의 DATE 컬럼은 `yyyy-MM-dd` 로컬 문자열로 저장한다.
library;

/// DateTime → 'yyyy-MM-dd' (로컬)
String dayKey(DateTime dt) {
  final y = dt.year.toString().padLeft(4, '0');
  final m = dt.month.toString().padLeft(2, '0');
  final d = dt.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

/// 'yyyy-MM-dd' → DateTime(로컬 자정)
DateTime parseDayKey(String key) {
  final p = key.split('-');
  return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

/// 하루의 경계 = Todd 기상시간(wakeHour, 기본 5시) 기준의 "논리적 오늘"
/// (세계관 통합 2026-08-15: Todd가 일어나는 순간 새 하루가 시작된다).
/// 새벽 2시는 아직 어제의 방이다.
DateTime logicalToday(DateTime now, {int dayStartHour = 5}) {
  final shifted = now.subtract(Duration(hours: dayStartHour));
  return DateTime(shifted.year, shifted.month, shifted.day);
}

/// 논리적 오늘의 dayKey
String logicalTodayKey(DateTime now, {int dayStartHour = 5}) =>
    dayKey(logicalToday(now, dayStartHour: dayStartHour));

/// 다음 논리적 날짜 경계 시각 (롤오버 타이머용)
DateTime nextRolloverAt(DateTime now, {int dayStartHour = 5}) {
  final today = logicalToday(now, dayStartHour: dayStartHour);
  return DateTime(today.year, today.month, today.day + 1, dayStartHour);
}

DateTime addDays(DateTime day, int n) =>
    DateTime(day.year, day.month, day.day + n);

/// 그 날짜가 속한 주의 월요일 dayKey (ISO 요일: 월=1)
String mondayKeyOf(String key) {
  final d = parseDayKey(key);
  return dayKey(addDays(d, -(d.weekday - 1)));
}

/// [todayKey] 기준 지난주 월요일
String lastMondayKeyOf(String todayKey) =>
    dayKey(addDays(parseDayKey(mondayKeyOf(todayKey)), -7));

/// 청구서는 논리적 월요일에만 연다 (§6.5)
bool isMondayKey(String key) => parseDayKey(key).weekday == DateTime.monday;
