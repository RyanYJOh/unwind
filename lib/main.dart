import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/tokens/typography.dart';
import 'features/today/today_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: UnwindApp()));
}

class UnwindApp extends StatelessWidget {
  const UnwindApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Unwind',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: UnwindType.fontFamily),
      // §8.2 Dynamic Type: 최대 1.3배까지, 그 이상은 클램프
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        final scale = math.min(
            mq.textScaler.scale(16) / 16, UnwindType.maxTextScale);
        return MediaQuery(
          data: mq.copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        );
      },
      // M0 감각 프로토타입은 lib/features/today/m0_prototype_screen.dart에 유지
      // (실기기 감각 검증용 — §13 M0 승인 전까지 보존)
      home: const TodayScreen(),
    );
  }
}
