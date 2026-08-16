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

    test('Todo 알림 ID는 실행 간 재현 가능한 양수다', () {
      final first = NotificationService.todoNotificationId('todo-123');
      expect(first, NotificationService.todoNotificationId('todo-123'));
      expect(first, greaterThanOrEqualTo(1000));
      expect(first, isNot(NotificationService.todoNotificationId('todo-124')));
    });
  });
}
