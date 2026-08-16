import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:unwind/features/today/m0_prototype_screen.dart';
import 'package:unwind/l10n/generated/app_localizations.dart';
import 'package:unwind/ui/ui.dart';
import 'package:unwind/widgets/pull_cord.dart';

/// M0 스모크 테스트 — 감각 자체는 실기기에서만 검증 가능하지만(§13),
/// 상호작용 흐름과 §14 일부 수용 기준은 여기서 자동 확인한다.
void main() {
  // 새 형광등 패널은 행이 높아 기본 테스트 뷰포트(800)에 5개가 안 들어간다
  // → iPhone 실기기 크기로 설정
  Future<void> setPhoneViewport(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('M0: 더미 5개가 표시되고, 완료해도 리스트에서 사라지지 않는다', (tester) async {
    await setPhoneViewport(tester);
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: M0PrototypeScreen(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(UnwindTodoTile), findsNWidgets(5));
    // v2: textPrimary 크로스페이드 폐기 — 텍스트는 한 겹
    expect(find.text('장보기'), findsOneWidget);

    // 체크 — 개정: 우측 스위치로 토글
    await tester.tap(
      find.descendant(
        of: find.widgetWithText(UnwindTodoTile, '장보기'),
        matching: find.byType(UnwindLampSwitch),
      ),
    );
    await tester.pump(); // 리빌드 프레임 (여기서 소등 애니메이션 시작)
    await tester.pump(const Duration(milliseconds: 600)); // 테마 이동 완료

    // §14: 완료한 항목이 리스트에서 사라지거나 순서가 바뀌지 않는다
    expect(find.byType(UnwindTodoTile), findsNWidgets(5));
    expect(find.text('장보기'), findsOneWidget);

    await tester.pumpWidget(const SizedBox()); // 타이머 정리
  });

  testWidgets('M0: 전등 줄 임계 이상 당기면 소등 시퀀스가 돌고 리셋이 노출된다', (tester) async {
    await setPhoneViewport(tester);
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: M0PrototypeScreen(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));

    // 임계(56px) 이상 당기기 — 저항 곡선 고려해 크게 당긴다
    await tester.drag(find.byType(PullCord), const Offset(0, 250));
    // 도미노: 5등 × 70ms + 소등 220ms ≈ 500ms
    await tester.pump(const Duration(milliseconds: 600));
    // 정적 500ms + Todd 1400ms + 별 2000ms
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump(const Duration(milliseconds: 2500));
    // 리셋 노출 대기 (시퀀스 후 3초)
    await tester.pump(const Duration(milliseconds: 1500));

    expect(
      find.text('Experience again from the start (M0 test)'),
      findsOneWidget,
    );

    // 리셋하면 처음 상태로
    await tester.tap(find.text('Experience again from the start (M0 test)'));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(UnwindTodoTile), findsNWidgets(5));

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('M0: 임계 미만으로 당기면 아무 일도 없다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: M0PrototypeScreen(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));

    await tester.drag(find.byType(PullCord), const Offset(0, 20));
    await tester.pump(const Duration(seconds: 2));

    // 시퀀스가 시작되지 않았으므로 리셋 버튼 없음
    expect(
      find.text('Experience again from the start (M0 test)'),
      findsNothing,
    );

    await tester.pumpWidget(const SizedBox());
  });
}
