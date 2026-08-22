import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unwind/ui/ui.dart';

/// UnwindTypewriterText (온보딩 2026-08-22) — 글자별 공개·문장부호 페이스·
/// 레이아웃 고정·Reduce Motion 즉시 표시.
void main() {
  /// 지금 보이는(투명이 아닌) 앞쪽 스팬의 텍스트.
  /// Text.rich는 전달한 스팬을 스타일 스팬으로 한 겹 감싼다 — 두 단계 안으로.
  String shown(WidgetTester tester) {
    final rich = tester.widget<RichText>(find.byType(RichText).first);
    final outer = rich.text as TextSpan;
    final ours = outer.children!.first as TextSpan;
    return (ours.children!.first as TextSpan).text ?? '';
  }

  Widget host(Widget child) => Directionality(
    textDirection: TextDirection.ltr,
    child: Center(child: child),
  );

  testWidgets('글자가 순서대로 나타나고 onDone이 불린다', (tester) async {
    var done = false;
    await tester.pumpWidget(
      host(
        UnwindTypewriterText(
          'abc',
          charInterval: const Duration(milliseconds: 100),
          onDone: () => done = true,
        ),
      ),
    );
    expect(shown(tester), '');
    await tester.pump(const Duration(milliseconds: 100));
    expect(shown(tester), 'a');
    await tester.pump(const Duration(milliseconds: 100));
    expect(shown(tester), 'ab');
    expect(done, false);
    await tester.pump(const Duration(milliseconds: 100));
    expect(shown(tester), 'abc');
    expect(done, true);
  });

  testWidgets('점(.)에서 길게 쉰다 — 말끝이 흐려지는 리듬', (tester) async {
    await tester.pumpWidget(
      host(
        const UnwindTypewriterText(
          'a.b',
          charInterval: Duration(milliseconds: 100),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(shown(tester), 'a.');
    // 점 뒤는 8배(800ms) — 700ms까지는 그대로다
    await tester.pump(const Duration(milliseconds: 700));
    expect(shown(tester), 'a.');
    await tester.pump(const Duration(milliseconds: 100));
    expect(shown(tester), 'a.b');
  });

  testWidgets('레이아웃은 처음부터 전체 문장 크기 — 타이핑 중에 안 흔들린다',
      (tester) async {
    await tester.pumpWidget(
      host(
        const UnwindTypewriterText(
          'hello world',
          charInterval: Duration(milliseconds: 50),
        ),
      ),
    );
    final before = tester.getSize(find.byType(RichText).first);
    await tester.pump(const Duration(milliseconds: 550)); // 전부 타이핑
    expect(tester.getSize(find.byType(RichText).first), before);
  });

  testWidgets('text가 바뀌면 같은 자리에서 처음부터 다시 친다', (tester) async {
    Widget build(String text) => host(
      UnwindTypewriterText(
        text,
        charInterval: const Duration(milliseconds: 100),
      ),
    );
    await tester.pumpWidget(build('ab'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(shown(tester), 'ab');
    await tester.pumpWidget(build('cd'));
    expect(shown(tester), '');
    await tester.pump(const Duration(milliseconds: 100));
    expect(shown(tester), 'c');
    await tester.pump(const Duration(milliseconds: 100));
    expect(shown(tester), 'cd');
  });

  testWidgets('Reduce Motion — 즉시 전체 표시 + onDone', (tester) async {
    var done = false;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: host(
          UnwindTypewriterText(
            'abc',
            charInterval: const Duration(milliseconds: 100),
            onDone: () => done = true,
          ),
        ),
      ),
    );
    expect(shown(tester), 'abc');
    await tester.pump();
    expect(done, true);
  });
}
