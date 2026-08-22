import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unwind/data/db/database.dart';
import 'package:unwind/data/repositories/todo_repository.dart';
import 'package:unwind/domain/services/day_rollover_service.dart';

/// 날짜별 조도 독립성 (QA 2026-08-22) — 어제의 미완 투두를 오늘 뒤늦게
/// 체크해도:
///   ① 오늘의 day 행(조도의 원천)은 건드리지 않는다
///   ② 어제의 봉인(finalT·restless)은 그대로다 — 역사는 바뀌지 않는다
///   ③ 어제 행에서는 peakProgress만 갱신된다
/// setDone이 todo.date 자신의 행에만 쓰고, upsertPeak이 봉인 컬럼을
/// 덮어쓰지 않는 것이 규칙의 근거다.
void main() {
  test('어제 투두를 늦게 체크해도 오늘 조도의 원천은 불변', () async {
    final db = UnwindDatabase.withExecutor(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = TodoRepository(db);
    const yesterday = '2026-08-21';
    const today = '2026-08-22';

    final lateTodo = await repo.add(title: '어제 남긴 등', date: yesterday);
    await repo.add(title: '오늘의 등', date: today);

    // 롤오버 봉인 — 어제는 불을 남긴 밤 (finalT=peak 0.0, restless)
    final rollover = DayRolloverService(db: db, onRollover: (_) {});
    await rollover.sealPastDays(DateTime(2026, 8, 22, 12));
    rollover.dispose();

    final sealed = (await db.dayDao.getDay(yesterday))!;
    expect(sealed.finalT, 0.0);
    expect(sealed.restless, true);

    // 어제의 등을 오늘 뒤늦게 끈다
    await repo.setDone(lateTodo, true);

    // ① 오늘 행은 생성조차 되지 않았다 — 오늘 조도 무영향
    expect(await db.dayDao.getDay(today), null);

    // ② 어제의 봉인은 그대로 — 방 조도(finalT)도, 다크서클(restless)도
    final after = (await db.dayDao.getDay(yesterday))!;
    expect(after.finalT, 0.0);
    expect(after.restless, true);

    // ③ 어제 행에서는 peak만 올라간다 (열람 조도는 finalT가 우선이라 불변)
    expect(after.peakProgress, 1.0);
  });
}
