import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unwind/domain/models/todd_state.dart';
import 'package:unwind/widgets/todd/ghost_contract.dart';
import 'package:unwind/widgets/todd/ghost_painter_view.dart';

/// iOS 홈 위젯용 Todd 스프라이트 추출기 (PRD 개정 2026-08-15).
///
/// 위젯(WidgetKit)에서는 Flutter 페인터를 실행할 수 없어서, 실제 렌더러
/// (GhostPainterView)로 모드별 정지 프레임을 PNG로 구워 위젯 에셋 카탈로그에
/// 넣는다. **캐릭터 외형을 바꾸면 반드시 재추출할 것**:
///
///   SPRITE_EXPORT=1 flutter test test/tools/widget_sprite_export_test.dart
///
/// 출력: ios/ToddWidget/Assets.xcassets/<이름>.imageset/ (Contents.json 포함,
/// 720×720 투명 PNG를 **3x**로 표기 — 1x로 두면 WidgetKit이 720pt로 읽어
/// 스냅샷 아카이브가 실패하고 placeholder에 고정된다).
/// 평소 `flutter test`에서는 skip된다.
class _Sprite {
  final String name;
  final ToddMode mode;
  final ToddDayActivity? activity;
  final double dazzle;
  final bool darkCircles;

  /// 유휴 위상 (신설 2026-08-15) — 위상 기반 연출(꾸벅 낙하·콧물 방울·
  /// 식은땀)의 대표 순간을 정지 프레임에 담기 위한 값. 0이면 연출이
  /// 시작 전이라 아예 안 보인다.
  final double phase;

  const _Sprite(
    this.name,
    this.mode, {
    this.activity,
    this.dazzle = 0.0,
    this.darkCircles = false,
    this.phase = 0.0,
  });

  _Sprite get withDarkCircles => _Sprite(
    '${name}_dc',
    mode,
    activity: activity,
    dazzle: dazzle,
    darkCircles: true,
    phase: phase,
  );
}

const _base = <_Sprite>[
  _Sprite('todd_asleep', ToddMode.asleep),
  _Sprite('todd_day_stretch', ToddMode.day, activity: ToddDayActivity.stretch),
  _Sprite('todd_day_coffee', ToddMode.day, activity: ToddDayActivity.coffee),
  _Sprite('todd_day_read', ToddMode.day, activity: ToddDayActivity.read),
  _Sprite('todd_day_doodle', ToddMode.day, activity: ToddDayActivity.doodle),
  _Sprite('todd_day_walk', ToddMode.day, activity: ToddDayActivity.walk),
  _Sprite('todd_day_hum', ToddMode.day, activity: ToddDayActivity.hum),
  _Sprite('todd_day_snack', ToddMode.day, activity: ToddDayActivity.snack),
  _Sprite('todd_day_dance', ToddMode.day, activity: ToddDayActivity.dance),
  _Sprite('todd_day_bubbles', ToddMode.day, activity: ToddDayActivity.bubbles),
  _Sprite('todd_day_rest', ToddMode.day, activity: ToddDayActivity.rest),
  // 밤 못 자는 상태 — 눈부심 임계 0.45 (§6 toddMode) 양쪽.
  // phase는 과장 연출(2026-08-15)의 대표 순간: squint는 식은땀이 또렷한
  // 중간 지점(sp=0.5), doze는 꾸벅 낙하 정점 근처(콧물 방울 최대).
  // dazzle 0.9 — 압착 눈·눈물·땀이 위젯 크기에서도 읽히는 세기.
  _Sprite('todd_night_squint', ToddMode.nightAwake, dazzle: 0.9, phase: 1.11),
  _Sprite('todd_night_doze', ToddMode.nightAwake, dazzle: 0.2, phase: 1.18),
];

void main() {
  final export = Platform.environment['SPRITE_EXPORT'] == '1';

  testWidgets(
    'export Todd sprites for the iOS widget',
    (tester) async {
      final outRoot = Directory('ios/ToddWidget/Assets.xcassets');
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
                    sleepiness: sprite.mode == ToddMode.asleep ? 1.0 : 0.2,
                    // 잠든 포즈는 allDone 이벤트가 만든다 (§7.2 어댑터와 동일)
                    event: sprite.mode == ToddMode.asleep
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
                    initialPhase: sprite.phase,
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
          '      "idiom" : "universal",\n'
          '      "scale" : "3x"\n'
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
