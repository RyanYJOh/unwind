import 'package:flutter_test/flutter_test.dart';
import 'package:unwind/data/db/database.dart';
import 'package:unwind/features/today/providers.dart';

/// 주간 스트립 창 규칙 (개정 2026-08-22) — 앰버 창은 오늘 하나뿐이고,
/// 지난 날의 결과는 restless(다크서클)로 구분한다. weekWindows가 days 행의
/// restless를 창 정보에 실어 나르는지 검증한다.
void main() {
  Day day(String date, {double? finalT, bool restless = false}) => Day(
    date: date,
    peakProgress: finalT ?? 0,
    lightsOutAt: null,
    finalT: finalT,
    restless: restless,
  );

  test('weekWindows — restless·finalT가 그날 창에 실린다', () {
    final windows = weekWindows(
      mondayKey: '2026-08-17',
      todayKey: '2026-08-20', // 목요일
      byDate: {
        '2026-08-17': day('2026-08-17', finalT: 1.0), // 다 끄고 잔 밤
        '2026-08-18': day('2026-08-18', finalT: 0.4, restless: true), // 남긴 밤
        // 8-19: 기록 없음 (빈 방)
      },
    );

    expect(windows.length, 7);

    final mon = windows[0];
    expect(mon.isPast, true);
    expect(mon.restless, false);
    expect(mon.finalT, 1.0);

    // 불을 남긴 밤 — 다크서클의 근거
    final tue = windows[1];
    expect(tue.restless, true);
    expect(tue.finalT, 0.4);

    // 기록 없는 날 — 캄캄한 창, 흔적 없음
    final wed = windows[2];
    expect(wed.restless, false);
    expect(wed.finalT, null);

    final thu = windows[3];
    expect(thu.isToday, true);
    expect(thu.restless, false);

    // 미래 — 얼굴 없는 빈 창
    expect(windows[4].isFuture, true);
    expect(windows[6].isFuture, true);
  });
}
