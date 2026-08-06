import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unwind/main.dart';
import 'package:unwind/widgets/lamp_row.dart';
import 'package:unwind/widgets/pull_cord.dart';

/// M0 스모크 테스트 — 감각 자체는 실기기에서만 검증 가능하지만(§13),
/// 상호작용 흐름과 §14 일부 수용 기준은 여기서 자동 확인한다.
void main() {
  testWidgets('M0: 더미 5개가 표시되고, 완료해도 리스트에서 사라지지 않는다',
      (tester) async {
    await tester.pumpWidget(const UnwindApp());
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(LampRow), findsNWidgets(5));
    // PrimaryText는 크로스페이드용으로 텍스트를 2겹 그린다 (§8.1)
    expect(find.text('장보기'), findsNWidgets(2));

    // 체크
    await tester.tap(find.text('장보기').first);
    await tester.pump(const Duration(milliseconds: 600)); // 테마 이동 완료

    // §14: 완료한 항목이 리스트에서 사라지거나 순서가 바뀌지 않는다
    expect(find.byType(LampRow), findsNWidgets(5));
    expect(find.text('장보기'), findsNWidgets(2));

    await tester.pumpWidget(const SizedBox()); // 타이머 정리
  });

  testWidgets('M0: 전등 줄 임계 이상 당기면 소등 시퀀스가 돌고 리셋이 노출된다',
      (tester) async {
    await tester.pumpWidget(const UnwindApp());
    await tester.pump(const Duration(milliseconds: 50));

    // 임계(56px) 이상 당기기 — 저항 곡선 고려해 크게 당긴다
    await tester.drag(find.byType(PullCord), const Offset(0, 250));
    // 도미노: 5등 × 70ms + 소등 220ms ≈ 500ms
    await tester.pump(const Duration(milliseconds: 600));
    // 정적 500ms + Lumi 1400ms + 별 2000ms
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump(const Duration(milliseconds: 2500));
    // 리셋 노출 대기 (시퀀스 후 3초)
    await tester.pump(const Duration(milliseconds: 1500));

    expect(find.text('처음부터 다시 체험하기 (M0 테스트용)'), findsOneWidget);

    // 리셋하면 처음 상태로
    await tester.tap(find.text('처음부터 다시 체험하기 (M0 테스트용)'));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(LampRow), findsNWidgets(5));

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('M0: 임계 미만으로 당기면 아무 일도 없다', (tester) async {
    await tester.pumpWidget(const UnwindApp());
    await tester.pump(const Duration(milliseconds: 50));

    await tester.drag(find.byType(PullCord), const Offset(0, 20));
    await tester.pump(const Duration(seconds: 2));

    // 시퀀스가 시작되지 않았으므로 리셋 버튼 없음
    expect(find.text('처음부터 다시 체험하기 (M0 테스트용)'), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });
}
