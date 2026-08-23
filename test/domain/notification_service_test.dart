import 'package:flutter_test/flutter_test.dart';
import 'package:unwind/domain/services/notification_service.dart';

void main() {
  group('Todo 알림 시각', () {
    test('06시 이후 시각은 논리 날짜의 같은 캘린더 날짜다', () {
      expect(
        todoDueAt(
          dateKey: '2026-08-06',
          scheduledTimeMinutes: 6 * 60,
          dayStartHour: 6,
        ),
        DateTime(2026, 8, 6, 6),
      );
    });

    test('06시 이전 시각은 논리 날짜의 다음 캘린더 날짜다', () {
      expect(
        todoDueAt(
          dateKey: '2026-08-06',
          scheduledTimeMinutes: 5 * 60 + 30,
          dayStartHour: 6,
        ),
        DateTime(2026, 8, 7, 5, 30),
      );
      expect(
        todoReminderAt(
          dateKey: '2026-08-06',
          scheduledTimeMinutes: 5 * 60 + 30,
          dayStartHour: 6,
        ),
        DateTime(2026, 8, 7, 5, 20),
      );
    });

    test('10분 전 시각이 지난 회차와 정확히 현재인 회차는 예약하지 않는다', () {
      final now = DateTime(2026, 8, 6, 8);
      expect(
        shouldScheduleTodoReminder(
          dueAt: DateTime(2026, 8, 6, 8, 10),
          now: now,
        ),
        false,
      );
      expect(
        shouldScheduleTodoReminder(
          dueAt: DateTime(2026, 8, 6, 8, 11),
          now: now,
        ),
        true,
      );
    });

    test('취침 알림은 bedtime 30분 전이다', () {
      expect(nightReminderClock(22), (hour: 21, minute: 30));
      expect(nightReminderClock(16), (hour: 15, minute: 30));
      expect(nightReminderClock(0), (hour: 23, minute: 30));
      expect(nightReminderClock(1), (hour: 0, minute: 30));
    });

    test('아침 인사는 wakeHour 1시간 뒤다', () {
      expect(morningGreetingClock(5), (hour: 6, minute: 0));
      expect(morningGreetingClock(12), (hour: 13, minute: 0));
      expect(morningGreetingClock(23), (hour: 0, minute: 0));
    });

    test('아침 인사는 발송 시각 전이면 오늘, 지난 뒤면 내일 울린다', () {
      // 기상 5시 → 인사 6시. 개수를 셀 방이 이 날짜로 정해진다.
      expect(
        morningGreetingFireDate(DateTime(2026, 8, 23, 2), 5),
        DateTime(2026, 8, 23), // 새벽 2시 — 오늘 6시가 아직 안 지났다
      );
      expect(
        morningGreetingFireDate(DateTime(2026, 8, 23, 6), 5),
        DateTime(2026, 8, 24), // 정각은 지난 것으로 본다 (예약 로직과 동일)
      );
      expect(
        morningGreetingFireDate(DateTime(2026, 8, 23, 22), 5),
        DateTime(2026, 8, 24), // 밤에 쓰면 내일 아침 몫을 센다
      );
      // 월말을 넘겨도 날짜가 정상 이월된다
      expect(
        morningGreetingFireDate(DateTime(2026, 8, 31, 23), 5),
        DateTime(2026, 9, 1),
      );
    });

    test('Todo 알림 ID는 실행 간 재현 가능한 양수다', () {
      final first = NotificationService.todoNotificationId('todo-123');
      expect(first, NotificationService.todoNotificationId('todo-123'));
      expect(first, greaterThanOrEqualTo(1000));
      expect(first, isNot(NotificationService.todoNotificationId('todo-124')));
    });
  });
}
