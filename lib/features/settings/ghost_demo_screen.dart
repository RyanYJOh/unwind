import 'package:flutter/material.dart';

import '../../domain/models/lumi_state.dart' show LumiMode, LumiDayActivity;
import '../../widgets/lumi/ghost_view.dart';

/// Rive 브리프 §6.4 — 검증용 데모 화면 (개발 전용, 배포 빌드에서 제거).
/// 슬라이더로 sleepiness를 스크럽하고 트리거 4종을 발사한다.
/// 이 화면이 동작하면 앱 본체 연결은 prop 배선뿐이다.
Future<void> showGhostDemoScreen(BuildContext context) {
  return Navigator.of(
    context,
    rootNavigator: true,
  ).push(MaterialPageRoute(builder: (_) => const GhostDemoScreen()));
}

class GhostDemoScreen extends StatefulWidget {
  const GhostDemoScreen({super.key});

  @override
  State<GhostDemoScreen> createState() => _GhostDemoScreenState();
}

class _GhostDemoScreenState extends State<GhostDemoScreen> {
  double _sleepiness = 0.0;
  GhostEvent? _event;
  int _tick = 0;

  /// 생활 모드 프리뷰 (개편 2026-08-08). null = 레거시(슬라이더).
  LumiMode? _mode;
  LumiDayActivity? _activity;
  double _dazzle = 0.8;

  void _fire(GhostEvent e) {
    setState(() {
      _event = e;
      _tick++;
    });
  }

  void _setActivity(LumiDayActivity a) {
    setState(() {
      _mode = LumiMode.day;
      _activity = a;
      _event = null;
      _tick++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F4EE),
      appBar: AppBar(
        title: const Text('Ghost demo (dev)'),
        backgroundColor: const Color(0xFFF7F4EE),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: GhostView(
                sleepiness: _sleepiness,
                event: _event,
                eventTick: _tick,
                size: 280,
                mode: _mode,
                activity: _activity,
                dazzle: _dazzle,
              ),
            ),
          ),
          // 생활 모드 프리뷰 — 낮 일과 7종 + 밤(눈부심/꾸벅) + 레거시
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              alignment: WrapAlignment.center,
              children: [
                for (final a in LumiDayActivity.values)
                  ChoiceChip(
                    label: Text(a.name),
                    selected: _mode == LumiMode.day && _activity == a,
                    onSelected: (_) => _setActivity(a),
                  ),
                ChoiceChip(
                  label: const Text('night 눈부심'),
                  selected: _mode == LumiMode.nightAwake && _dazzle > 0.5,
                  onSelected: (_) => setState(() {
                    _mode = LumiMode.nightAwake;
                    _activity = null;
                    _dazzle = 0.9;
                    _event = null;
                    _tick++;
                  }),
                ),
                ChoiceChip(
                  label: const Text('night 꾸벅'),
                  selected: _mode == LumiMode.nightAwake && _dazzle <= 0.5,
                  onSelected: (_) => setState(() {
                    _mode = LumiMode.nightAwake;
                    _activity = null;
                    _dazzle = 0.15;
                    _event = null;
                    _tick++;
                  }),
                ),
                ChoiceChip(
                  label: const Text('legacy'),
                  selected: _mode == null,
                  onSelected: (_) => setState(() {
                    _mode = null;
                    _activity = null;
                  }),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                const Text('sleepiness'),
                Expanded(
                  child: Slider(
                    value: _sleepiness,
                    onChanged: (v) => setState(() => _sleepiness = v),
                  ),
                ),
                Text(_sleepiness.toStringAsFixed(2)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: () => _fire(GhostEvent.checkOff),
                  child: const Text('checkOff'),
                ),
                OutlinedButton(
                  onPressed: () => _fire(GhostEvent.allDone),
                  child: const Text('allDone'),
                ),
                OutlinedButton(
                  // allDone 해제는 event를 비우는 것으로 (어댑터 규약과 동일)
                  onPressed: () => setState(() {
                    _event = null;
                    _tick++;
                  }),
                  child: const Text('wake (allDone 해제)'),
                ),
                OutlinedButton(
                  onPressed: () => _fire(GhostEvent.wakeUpHappy),
                  child: const Text('happy'),
                ),
                // 톡 건드리기 (개편 2026-08-12) — 반응은 렌더러가 모드를 보고
                // 고른다: 깨어있으면 간지럼, 졸리면 실눈 두리번, 자면 무반응.
                OutlinedButton(
                  onPressed: () => _fire(GhostEvent.poke),
                  child: const Text('poke (톡)'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
