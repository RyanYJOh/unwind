import 'package:flutter_test/flutter_test.dart';
import 'package:unwind/domain/services/brightness_engine.dart';

/// §5 조도 엔진 · §14 수용 기준 검증
void main() {
  group('§5.1 진행률', () {
    test('0개일 때 0으로 나누지 않는다', () {
      expect(BrightnessEngine.rawProgress(doneCount: 0, totalCount: 0), 0.0);
    });

    test('기본 계산', () {
      expect(BrightnessEngine.rawProgress(doneCount: 1, totalCount: 4), 0.25);
    });
  });

  group('§5.2 단조 감소 규칙', () {
    test('수용 기준: 3개 중 1개 완료 후 4개를 추가해도 조도가 되돌아가지 않는다', () {
      final e = BrightnessEngine();
      // 3개 중 1개 완료 → peak = 1/3
      e.onItemCompleted(doneCount: 1, totalCount: 3);
      final tAfterComplete = e.t(doneCount: 1, totalCount: 3);
      expect(tAfterComplete, closeTo(1 / 3, 1e-9));

      // 4개 추가 → total 7, raw는 1/7로 떨어지지만 t 유지
      e.onItemAdded(doneCount: 1, totalCount: 7);
      expect(e.t(doneCount: 1, totalCount: 7), tAfterComplete);
    });

    test('수용 기준: 완료를 취소하면 조도가 정확히 되돌아간다', () {
      final e = BrightnessEngine();
      e.onItemCompleted(doneCount: 1, totalCount: 3);
      e.onItemCompleted(doneCount: 2, totalCount: 3);
      expect(e.t(doneCount: 2, totalCount: 3), closeTo(2 / 3, 1e-9));

      // 하나 취소 → raw = 1/3, 명시적 되돌리기이므로 하강 허용
      e.onItemUncompleted(doneCount: 1, totalCount: 3);
      expect(e.t(doneCount: 1, totalCount: 3), closeTo(1 / 3, 1e-9));
    });

    test('삭제 시 peak = max(peak, raw) — 어두워질 수는 있어도 밝아지지 않는다', () {
      final e = BrightnessEngine();
      e.onItemCompleted(doneCount: 1, totalCount: 4); // peak = 0.25
      // 미완료 항목 2개 삭제 → done 1 / total 2, raw = 0.5
      e.onItemDeleted(doneCount: 1, totalCount: 2);
      expect(e.peakProgress, 0.5);
      // 완료 항목이 남은 상태에서 삭제로 raw가 떨어져도 peak 유지
      e.onItemDeleted(doneCount: 1, totalCount: 4);
      expect(e.peakProgress, 0.5);
    });
  });

  group('§5.3 경계 조건', () {
    test('수용 기준: 할 일 0개일 때 t = 0.15', () {
      final e = BrightnessEngine();
      expect(e.t(doneCount: 0, totalCount: 0), BrightnessEngine.emptyRoomT);
      expect(BrightnessEngine.emptyRoomT, 0.15);
    });

    test('수용 기준: 전등 줄을 당긴 뒤 항목을 추가해도 t = 1.0 유지', () {
      final e = BrightnessEngine();
      e.onItemCompleted(doneCount: 1, totalCount: 2);
      e.pullCord();
      expect(e.t(doneCount: 1, totalCount: 2), 1.0);

      // Lumi 취침 후 항목 추가
      e.onItemAdded(doneCount: 1, totalCount: 3);
      expect(e.t(doneCount: 1, totalCount: 3), 1.0);
    });

    test('자정 롤오버 후 새 날의 값으로 재계산', () {
      final e = BrightnessEngine();
      e.onItemCompleted(doneCount: 2, totalCount: 2);
      e.pullCord();
      e.rollover();
      expect(e.lightsOut, false);
      expect(e.t(doneCount: 0, totalCount: 0), BrightnessEngine.emptyRoomT);
      expect(e.t(doneCount: 0, totalCount: 3), 0.0);
    });
  });
}
