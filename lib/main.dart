import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'core/tokens/typography.dart';
import 'features/today/m0_prototype_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const UnwindApp());
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
      home: const M0PrototypeScreen(),
    );
  }
}
