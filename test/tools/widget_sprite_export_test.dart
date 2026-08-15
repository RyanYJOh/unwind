import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unwind/domain/models/lumi_state.dart';
import 'package:unwind/widgets/lumi/ghost_contract.dart';
import 'package:unwind/widgets/lumi/ghost_painter_view.dart';

/// iOS 홈 위젯용 Lumi 스프라이트 추출기 (PRD 개정 2026-08-15).
///
/// 위젯(WidgetKit)에서는 Flutter 페인터를 실행할 수 없어서, 실제 렌더러
/// (GhostPainterView)로 모드별 정지 프레임을 PNG로 구워 위젯 에셋 카탈로그에
/// 넣는다. **캐릭터 외형을 바꾸면 반드시 재추출할 것**:
///
///   SPRITE_EXPORT=1 flutter test test/tools/widget_sprite_export_test.dart
///
/// 출력: ios/LumiWidget/Assets.xcassets/<이름>.imageset/ (Contents.json 포함,
/// 720×720 투명 PNG). 평소 `flutter test`에서는 skip된다.
class _Sprite {
  final String name;
  final LumiMode mode;
  final LumiDayActivity? activity;
  final double dazzle;
  final bool darkCircles;

  const _Sprite(
    this.name,
    this.mode, {
    this.activity,
    this.dazzle = 0.0,
    this.darkCircles = false,
  });

  _Sprite get withDarkCircles => _Sprite(
    '${name}_dc',
    mode,
    activity: activity,
    dazzle: dazzle,
    darkCircles: true,
  );
}

const _base = <_Sprite>[
  _Sprite('lumi_asleep', LumiMode.asleep),
  _Sprite('lumi_day_stretch', LumiMode.day, activity: LumiDayActivity.stretch),
  _Sprite('lumi_day_coffee', LumiMode.day, activity: LumiDayActivity.coffee),
  _Sprite('lumi_day_read', LumiMode.day, activity: LumiDayActivity.read),
  _Sprite('lumi_day_doodle', LumiMode.day, activity: LumiDayActivity.doodle),
  _Sprite('lumi_day_walk', LumiMode.day, activity: LumiDayActivity.walk),
  _Sprite('lumi_day_hum', LumiMode.day, activity: LumiDayActivity.hum),
  _Sprite('lumi_day_snack', LumiMode.day, activity: LumiDayActivity.snack),
  _Sprite('lumi_day_dance', LumiMode.day, activity: LumiDayActivity.dance),
  _Sprite('lumi_day_bubbles', LumiMode.day, activity: LumiDayActivity.bubbles),
  _Sprite('lumi_day_rest', LumiMode.day, activity: LumiDayActivity.rest),
  // 밤 못 자는 상태 — 눈부심 임계 0.45 (§6 lumiMode) 양쪽
  _Sprite('lumi_night_squint', LumiMode.nightAwake, dazzle: 0.8),
  _Sprite('lumi_night_doze', LumiMode.nightAwake, dazzle: 0.2),
];

void main() {
  final export = Platform.environment['SPRITE_EXPORT'] == '1';

  testWidgets(
    'export Lumi sprites for the iOS widget',
    (tester) async {
      final outRoot = Directory('ios/LumiWidget/Assets.xcassets');
      final sprites = [for (final s in _base) ...[s, s.withDarkCircles]];

      for (final sprite in sprites) {
        final key = GlobalKey();
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: RepaintBoundary(
                key: key,
                child: SizedBox(
                  width: 240,
                  height: 240,
                  child: GhostPainterView(
                    sleepiness: sprite.mode == LumiMode.asleep ? 1.0 : 0.2,
                    // 잠든 포즈는 allDone 이벤트가 만든다 (§7.2 어댑터와 동일)
                    event: sprite.mode == LumiMode.asleep
                        ? GhostEvent.allDone
                        : null,
                    eventTick: 1,
                    size: 240,
                    // 장식 타이머(하품·깜빡임)를 멈춰 프레임을 결정적으로
                    reduceMotion: true,
                    mode: sprite.mode,
                    activity: sprite.activity,
                    dazzle: sprite.dazzle,
                    darkCircles: sprite.darkCircles,
                  ),
                ),
              ),
            ),
          ),
        );

        // 몸통 PNG 비동기 로드 대기 (실 IO — runAsync 필요)
        for (var i = 0; i < 10; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 60)),
          );
          await tester.pump();
        }
        // 유휴 위상(부유·zzz)이 자연스러운 중간 지점에 오도록 진행
        await tester.pump(const Duration(milliseconds: 700));

        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final bytes = await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 3.0);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          image.dispose();
          return data!.buffer.asUint8List();
        });

        final dir = Directory('${outRoot.path}/${sprite.name}.imageset')
          ..createSync(recursive: true);
        File('${dir.path}/${sprite.name}.png').writeAsBytesSync(bytes!);
        File('${dir.path}/Contents.json').writeAsStringSync(
          '{\n'
          '  "images" : [\n'
          '    {\n'
          '      "filename" : "${sprite.name}.png",\n'
          '      "idiom" : "universal"\n'
          '    }\n'
          '  ],\n'
          '  "info" : {\n'
          '    "author" : "xcode",\n'
          '    "version" : 1\n'
          '  }\n'
          '}\n',
        );
      }
    },
    skip: !export,
  );
}
