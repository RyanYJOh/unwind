import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unwind/domain/models/lumi_state.dart';
import 'package:unwind/widgets/lumi/ghost_contract.dart';
import 'package:unwind/widgets/lumi/ghost_painter_view.dart';

/// GhostPainterView — 브리프 계약 스모크 (블렌드 스크럽 + 이벤트 + 정리)
void main() {
  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: Center(child: child)),
    ),
  );

  testWidgets('sleepiness 스크럽 0→1과 이벤트 발사에 크래시가 없다', (tester) async {
    for (final t in [0.0, 0.25, 0.5, 0.75, 1.0]) {
      await pump(tester, GhostPainterView(sleepiness: t));
      await tester.pump(const Duration(milliseconds: 120));
      expect(find.byType(GhostPainterView), findsOneWidget);
    }

    // checkOff 통통 (타임라인 D, 0.5s)
    await pump(
      tester,
      const GhostPainterView(
        sleepiness: 0.5,
        event: GhostEvent.checkOff,
        eventTick: 1,
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    // happy (타임라인 F)
    await pump(
      tester,
      const GhostPainterView(
        sleepiness: 0.5,
        event: GhostEvent.wakeUpHappy,
        eventTick: 2,
      ),
    );
    await tester.pump(const Duration(milliseconds: 1700));

    // allDone → fallAsleep(zzz) → 해제
    await pump(
      tester,
      const GhostPainterView(
        sleepiness: 1.0,
        event: GhostEvent.allDone,
        eventTick: 3,
      ),
    );
    await tester.pump(const Duration(milliseconds: 1500));
    await pump(tester, const GhostPainterView(sleepiness: 0.0, eventTick: 4));
    await tester.pump(const Duration(milliseconds: 1500));

    // 타이머 정리 (하품·깜빡임)
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('Reduce Motion이면 부유 틱이 돌지 않는다', (tester) async {
    await pump(
      tester,
      const GhostPainterView(sleepiness: 0.3, reduceMotion: true),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(GhostPainterView), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('모든 낮 활동과 밤 눈꺼풀 상태가 크래시 없이 그려진다', (tester) async {
    for (final activity in LumiDayActivity.values) {
      await pump(
        tester,
        GhostPainterView(
          sleepiness: 0.1,
          mode: LumiMode.day,
          activity: activity,
          reduceMotion: true,
        ),
      );
      await tester.pump();
      expect(find.byType(GhostPainterView), findsOneWidget);
    }

    for (final dazzle in [0.0, 0.5, 1.0]) {
      await pump(
        tester,
        GhostPainterView(
          sleepiness: 0.6,
          mode: LumiMode.nightAwake,
          dazzle: dazzle,
          reduceMotion: true,
        ),
      );
      await tester.pump();
      expect(find.byType(GhostPainterView), findsOneWidget);
    }

    await tester.pumpWidget(const SizedBox());
  });
}
