import 'package:flutter_test/flutter_test.dart';
import 'package:unwind/core/utils/dates.dart';

/// 하루의 경계 = Todd 기상시간 (기본 5시, 세계관 통합 2026-08-15)
/// — 이 시각 전까지는 어제의 방이다 (§4.5, §5.3).
void main() {
  test('새벽 2시는 아직 어제의 방이다', () {
    expect(logicalTodayKey(DateTime(2026, 8, 6, 2, 0)), '2026-08-05');
  });

  test('기상시간(05시) 정각부터 새 날이다', () {
    expect(logicalTodayKey(DateTime(2026, 8, 6, 5, 0)), '2026-08-06');
    expect(logicalTodayKey(DateTime(2026, 8, 6, 4, 59)), '2026-08-05');
  });

  test('다음 롤오버 시각', () {
    expect(nextRolloverAt(DateTime(2026, 8, 6, 12)), DateTime(2026, 8, 7, 5));
    expect(
      nextRolloverAt(DateTime(2026, 8, 6, 2)),
      DateTime(2026, 8, 6, 5),
    ); // 어제의 방에 있을 때는 오늘 기상시간
  });

  test('기상시간 설정을 따른다', () {
    expect(
      logicalTodayKey(DateTime(2026, 8, 6, 6, 30), dayStartHour: 7),
      '2026-08-05',
    );
    expect(
      nextRolloverAt(DateTime(2026, 8, 6, 12), dayStartHour: 7),
      DateTime(2026, 8, 7, 7),
    );
  });

  test('dayKey 왕복', () {
    expect(dayKey(parseDayKey('2026-01-05')), '2026-01-05');
  });

  test('월요일 판정 · 지난주 월요일', () {
    expect(isMondayKey('2026-08-03'), true); // 월
    expect(isMondayKey('2026-08-06'), false); // 목
    expect(mondayKeyOf('2026-08-06'), '2026-08-03');
    expect(lastMondayKeyOf('2026-08-10'), '2026-08-03'); // 월 → 지난주 월
    expect(lastMondayKeyOf('2026-08-06'), '2026-07-27');
  });
}
