import 'package:flutter_test/flutter_test.dart';
import 'package:unwind/core/utils/dates.dart';

/// dayStartHour(기본 6시) 기준 논리적 날짜 (§4.5, §5.3)
void main() {
  test('새벽 2시는 아직 어제의 방이다', () {
    expect(logicalTodayKey(DateTime(2026, 8, 6, 2, 0)), '2026-08-05');
  });

  test('오전 6시 정각부터 새 날이다', () {
    expect(logicalTodayKey(DateTime(2026, 8, 6, 6, 0)), '2026-08-06');
    expect(logicalTodayKey(DateTime(2026, 8, 6, 5, 59)), '2026-08-05');
  });

  test('다음 롤오버 시각', () {
    expect(nextRolloverAt(DateTime(2026, 8, 6, 12)),
        DateTime(2026, 8, 7, 6));
    expect(nextRolloverAt(DateTime(2026, 8, 6, 2)),
        DateTime(2026, 8, 6, 6)); // 어제의 방에 있을 때는 오늘 아침 6시
  });

  test('dayKey 왕복', () {
    expect(dayKey(parseDayKey('2026-01-05')), '2026-01-05');
  });
}
