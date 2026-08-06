import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:unwind/core/tokens/color_ramp.dart';

/// WCAG 상대 휘도
double _luminance(Color c) {
  double lin(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b);
}

/// WCAG 대비율
double _contrast(Color a, Color b) {
  final la = _luminance(a), lb = _luminance(b);
  final hi = math.max(la, lb), lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  group('§8.1 조도 램프', () {
    test('정거장 t 값에서 정확히 정거장 색을 돌려준다', () {
      for (final stop in kRamp) {
        final c = lerpRamp(stop.t);
        expect(c.bg.toARGB32(), stop.bg.toARGB32(),
            reason: 't=${stop.t} bg');
        expect(c.lamp.toARGB32(), stop.lamp.toARGB32(),
            reason: 't=${stop.t} lamp');
      }
    });

    test('범위 밖 t는 클램프된다', () {
      expect(lerpRamp(-0.5).bg.toARGB32(), kRamp.first.bg.toARGB32());
      expect(lerpRamp(1.5).bg.toARGB32(), kRamp.last.bg.toARGB32());
    });

    test('중간값은 회색 진흙이 아니다 — OKLab 보간 sanity check', () {
      // S2(노을)~S3(땅거미) 중간: RGB 직선 보간이라면 채도가 죽는다.
      final mid = lerpRamp(0.625).bg;
      // 채도(max-min)가 어느 정도 살아 있어야 한다
      final r = mid.r, g = mid.g, b = mid.b;
      final spread =
          [r, g, b].reduce(math.max) - [r, g, b].reduce(math.min);
      expect(spread, greaterThan(0.08),
          reason: '중간 색의 채도가 죽었다: $mid');
    });

    test('textFlipProgress는 kTextFlipT(0.67) 기준으로 뒤집힌다', () {
      // 조정됨(사용자 승인 2026-08-06): 원래 0.62 → 0.67 (§12 대비 충돌 해소)
      expect(lerpRamp(0.66).textFlipProgress, 0.0);
      expect(lerpRamp(0.68).textFlipProgress, 1.0);
      expect(kTextFlipT, 0.67);
    });
  });

  group('§12 접근성 — 대비 자동 검증', () {
    // §8.1 원값은 S3 구간에서 4.5:1이 불가능해 S3 배경 계열과 전환점을
    // 조정함(사용자 승인 2026-08-06). color_ramp.dart의 조정 주석 참조.
    test('t=0.00~1.00, 0.05 간격 전 구간에서 textPrimary/bg 대비 ≥ 4.5:1', () {
      final failures = <String>[];
      for (var i = 0; i <= 20; i++) {
        final t = i * 0.05;
        final c = lerpRamp(t);
        // 크로스페이드로 실제 표시되는 텍스트 색
        final text = c.textFlipProgress < 0.5
            ? c.textPrimaryDark
            : c.textPrimaryLight;
        final ratio = _contrast(text, c.bg);
        if (ratio < 4.5) {
          failures.add(
              't=${t.toStringAsFixed(2)} → ${ratio.toStringAsFixed(2)}:1');
        }
      }
      expect(failures, isEmpty,
          reason: '대비 4.5:1 미달 구간: ${failures.join(', ')}');
    });
  });
}
