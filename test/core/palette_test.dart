import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:unwind/core/tokens/palette.dart';

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
  // 텍스트를 얹을 수 있는 모든 면 (§12는 이 위에서 4.5:1을 요구한다)
  const surfaces = <String, Color>{
    'ink': UnwindColors.ink,
    'surface': UnwindColors.surface,
    'surfaceAlt': UnwindColors.surfaceAlt,
  };

  group('§12 접근성 — 디자인 시스템 v2 팔레트 대비', () {
    test('본문 3색은 모든 면에서 4.5:1 이상', () {
      const texts = <String, Color>{
        'textPrimary': UnwindColors.textPrimary,
        'textSecondary': UnwindColors.textSecondary,
        'textMuted': UnwindColors.textMuted,
      };
      for (final s in surfaces.entries) {
        for (final t in texts.entries) {
          final ratio = _contrast(t.value, s.value);
          expect(
            ratio,
            greaterThanOrEqualTo(4.5),
            reason: '${t.key} on ${s.key} = ${ratio.toStringAsFixed(2)}:1',
          );
        }
      }
    });

    test('포인트 컬러 위의 글자색도 4.5:1 이상', () {
      expect(
        _contrast(UnwindColors.onAccent, UnwindColors.accent),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(UnwindColors.onDanger, UnwindColors.danger),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('포인트 컬러 자체는 모든 면에서 3:1 이상 (비텍스트 대비)', () {
      for (final s in surfaces.entries) {
        for (final a in {
          'accent': UnwindColors.accent,
          'danger': UnwindColors.danger,
        }.entries) {
          expect(
            _contrast(a.value, s.value),
            greaterThanOrEqualTo(3.0),
            reason: '${a.key} on ${s.key}',
          );
        }
      }
    });
  });

  group('빛(조도)의 색 파생', () {
    test('window(0) = 소등된 캄캄한 창, window(1) = 앰버', () {
      expect(
        UnwindColors.window(0).toARGB32(),
        UnwindColors.darkWindow.toARGB32(),
      );
      expect(UnwindColors.window(1).toARGB32(), UnwindColors.accent.toARGB32());
    });

    test('범위 밖 light는 클램프된다', () {
      expect(
        UnwindColors.window(-1).toARGB32(),
        UnwindColors.darkWindow.toARGB32(),
      );
      expect(UnwindColors.window(2).toARGB32(), UnwindColors.accent.toARGB32());
    });

    test('중간값은 회색 진흙이 아니다 — OKLab 보간 sanity check', () {
      final mid = UnwindColors.window(0.5);
      final spread =
          [mid.r, mid.g, mid.b].reduce(math.max) -
          [mid.r, mid.g, mid.b].reduce(math.min);
      expect(spread, greaterThan(0.08), reason: '중간 색의 채도가 죽었다: $mid');
    });

    test('빛이 늘어나면 창은 단조 증가로 밝아진다', () {
      var prev = _luminance(UnwindColors.window(0));
      for (var i = 1; i <= 10; i++) {
        final l = _luminance(UnwindColors.window(i / 10));
        expect(l, greaterThan(prev), reason: 'light=${i / 10}');
        prev = l;
      }
    });
  });
}
