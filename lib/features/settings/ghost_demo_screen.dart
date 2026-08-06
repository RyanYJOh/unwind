import 'package:flutter/material.dart';

import '../../widgets/lumi/ghost_view.dart';

/// Rive 브리프 §6.4 — 검증용 데모 화면 (개발 전용, 배포 빌드에서 제거).
/// 슬라이더로 sleepiness를 스크럽하고 트리거 4종을 발사한다.
/// 이 화면이 동작하면 앱 본체 연결은 prop 배선뿐이다.
Future<void> showGhostDemoScreen(BuildContext context) {
  return Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute(builder: (_) => const GhostDemoScreen()),
  );
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

  void _fire(GhostEvent e) {
    setState(() {
      _event = e;
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
                fallbackBuilder: (context) => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    '.riv 파일이 아직 없어요\n(assets/rive/ghost.riv)\n\nRive 에디터 + MCP로 캐릭터를 만들면\n이 자리에 나타납니다',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
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
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
