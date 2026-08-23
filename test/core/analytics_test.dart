import 'package:flutter_test/flutter_test.dart';
import 'package:unwind/core/analytics/analytics.dart';

void main() {
  group('ToddAnalytics.timeOfDay', () {
    test('오늘 날짜에 시·분을 붙인 DateTime을 만든다', () {
      final t = ToddAnalytics.timeOfDay(7, 30);
      final n = DateTime.now();
      expect(t.year, n.year);
      expect(t.month, n.month);
      expect(t.day, n.day);
      expect(t.hour, 7);
      expect(t.minute, 30);
    });
  });

  group('ToddAnalytics.todoEventProps', () {
    test('target_date·repeat_type·time을 올바르게 만든다', () {
      final props = ToddAnalytics.todoEventProps(
        title: '물 마시기',
        targetDateKey: '2026-08-23',
        hasMemo: true,
        isAutoPostpone: false,
        repeatType: 'daily',
        scheduledTimeMinutes: 9 * 60,
      );
      expect(props['title'], '물 마시기');
      expect(props['has_memo'], true);
      expect(props['repeat_type'], 'daily');
      expect((props['target_date'] as DateTime).day, 23);
      expect((props['time'] as DateTime).hour, 9);
    });

    test('반복·시간 없으면 키를 생략한다', () {
      final props = ToddAnalytics.todoEventProps(
        title: '운동',
        targetDateKey: '2026-08-01',
        hasMemo: false,
        isAutoPostpone: true,
      );
      expect(props.containsKey('repeat_type'), false);
      expect(props.containsKey('time'), false);
    });
  });
}
