import 'package:flutter_test/flutter_test.dart';
import 'package:unwind/data/db/tables/tables.dart';
import 'package:unwind/domain/services/brightness_engine.dart';
import 'package:unwind/domain/services/widget_snapshot_service.dart';

void main() {
  WidgetSnapshot snap({
    Iterable<TodoStatus> statuses = const [],
    bool lightsOut = false,
    double peak = 0,
  }) => WidgetSnapshot.fromTodos(
    dayKey: '2026-08-16',
    statuses: statuses,
    lightsOut: lightsOut,
    peakProgress: peak,
    darkCircles: false,
    wakeHour: 5,
    bedtimeHour: 22,
    languageCode: 'en',
  );

  test('deferred는 개수에서 빠진다', () {
    final s = snap(
      statuses: [
        TodoStatus.pending,
        TodoStatus.pending,
        TodoStatus.done,
        TodoStatus.deferred,
      ],
    );
    expect(s.remaining, 2);
    expect(s.total, 3);
  });

  test('빈 방은 emptyRoomT', () {
    expect(snap().brightness, BrightnessEngine.emptyRoomT);
    expect(snap().total, 0);
    expect(snap().remaining, 0);
  });

  test('소등하면 t=1, 아니면 peak', () {
    expect(
      snap(statuses: [TodoStatus.pending], lightsOut: true, peak: 0.2)
          .brightness,
      1.0,
    );
    expect(
      snap(statuses: [TodoStatus.pending], peak: 0.4).brightness,
      0.4,
    );
  });
}
