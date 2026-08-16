import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/settings_controller.dart';
import 'providers.dart';

/// 전등 줄 코치마크를 띄울지. [onNewTodoAdded]가 조건을 통과하면 true.
final pullCordCoachVisibleProvider =
    NotifierProvider<PullCordCoachController, bool>(
      PullCordCoachController.new,
    );

class PullCordCoachController extends Notifier<bool> {
  @override
  bool build() => false;

  /// 새 할 일을 오늘 방에 넣은 뒤 호출. 온보딩 직후 + 오늘 2개 이상이면 표시.
  Future<void> onNewTodoAdded(String date) async {
    if (state) return;

    final settings = ref.read(settingsControllerProvider).value;
    if (settings == null) return;
    if (settings.pullCordCoachShown) return;
    if (!settings.pullCordCoachAwaiting) return;

    final today = ref.read(todayKeyProvider);
    if (date != today) return;

    final (_, total) = await ref
        .read(databaseProvider)
        .todoDao
        .countsForDate(date);
    if (total < 2) return;

    state = true;
  }

  Future<void> dismiss() async {
    if (!state) return;
    state = false;

    final ctrl = ref.read(settingsControllerProvider.notifier);
    await ctrl.setPullCordCoachShown();
  }
}
