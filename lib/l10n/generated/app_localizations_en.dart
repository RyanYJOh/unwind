// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Todd';

  @override
  String get today => 'Today';

  @override
  String get emptyRoomTitle => 'No to-do items';

  @override
  String get emptyRoomSubtitle => 'Wait.. the light can\'t be turned off?';

  @override
  String get billBadge => 'Bill';

  @override
  String get addTaskLabel => 'Add a task';

  @override
  String get endDayLabel => 'End the day';

  @override
  String get pullCordCoach => 'Pull the handle all the way down.';

  @override
  String get lampOn => 'On';

  @override
  String get lampOff => 'Off';

  @override
  String weekNumber(int n) {
    return 'Week $n';
  }

  @override
  String get weekProgressLabel => 'This week\'s progress';

  @override
  String get weekAllDone => 'All done this week';

  @override
  String get weekEmpty => 'Nothing planned this week yet';

  @override
  String get weekIncompleteOnly => 'Incomplete tasks';

  @override
  String addToDay(String day) {
    return 'Add to $day';
  }

  @override
  String openDay(String day) {
    return 'Open $day';
  }

  @override
  String get lastWeek => 'Last week';

  @override
  String get nextWeek => 'Next week';

  @override
  String weekRange(String from, String to) {
    return '$from – $to';
  }

  @override
  String get thisWeek => 'This week';

  @override
  String get thisWeekLabel => 'This week';

  @override
  String get collapse => 'Collapse';

  @override
  String get add => 'Add';

  @override
  String get edit => 'Edit';

  @override
  String get delete => 'Delete';

  @override
  String get deleteThisTask => 'Delete only this task';

  @override
  String get deleteFutureRecurring => 'Delete this and all future repeats';

  @override
  String get close => 'Close';

  @override
  String get save => 'Save';

  @override
  String get share => 'Share';

  @override
  String get cancel => 'Cancel';

  @override
  String get taskHint => 'Task';

  @override
  String get addMemo => 'Add a note';

  @override
  String get toddSleepingNotice => 'Todd\'s asleep. This will go in tomorrow';

  @override
  String get toddPokeLabel => 'Todd';

  @override
  String get toddAway => 'I\'m in today\'s room';

  @override
  String get toastTaskDeleted => 'To-do deleted';

  @override
  String get undo => 'Undo';

  @override
  String get toastTaskAdded => 'A new light is on';

  @override
  String get dateToday => 'Today';

  @override
  String get dateTomorrow => 'Tomorrow';

  @override
  String get dateDayAfter => 'In 2 days';

  @override
  String get chooseDate => 'Choose date';

  @override
  String get repeatSection => 'Repeat';

  @override
  String get repeatNone => 'No repeat';

  @override
  String get repeatDaily => 'Every day';

  @override
  String get repeatWeekdays => 'Weekdays';

  @override
  String get repeatWeekly => 'Weekly';

  @override
  String get repeatMonthly => 'Monthly';

  @override
  String repeatEveryWeekday(String weekday) {
    return 'Every $weekday';
  }

  @override
  String repeatEveryMonthDay(String day) {
    return 'Every $day';
  }

  @override
  String get weekdaysShort => 'Mon,Tue,Wed,Thu,Fri,Sat,Sun';

  @override
  String get weekdaysLong =>
      'Monday,Tuesday,Wednesday,Thursday,Friday,Saturday,Sunday';

  @override
  String get monthsShort => 'Jan,Feb,Mar,Apr,May,Jun,Jul,Aug,Sep,Oct,Nov,Dec';

  @override
  String monthDay(String monthName, int month, int day) {
    return '$monthName $day';
  }

  @override
  String get billTitle => 'Weekly Electric Bill';

  @override
  String billTasksClosed(int done, int total) {
    return '$done / $total';
  }

  @override
  String get billTasksCaption => 'tasks closed last week';

  @override
  String billTotalCaption(String kwh) {
    return '$kwh kWh left burning overnight';
  }

  @override
  String get billMondayOnly => 'The bill opens on Mondays';

  @override
  String get billMondayOnlyBody =>
      'Meanwhile, let\'s smash\nthis week\'s to-dos!';

  @override
  String wonAmount(String amount) {
    return '₩$amount';
  }

  @override
  String get sleepDeep => 'Todd had perfect sleep';

  @override
  String get sleepWell => 'Todd slept fine';

  @override
  String get sleepTossed => 'Todd tossed and turned a little';

  @override
  String get sleepBarely => 'Todd barely closed an eye';

  @override
  String get sleepNone => 'Todd stayed awake all night';

  @override
  String nightsOut(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'You turned the lights out on $count nights this week',
      one: 'You turned the lights out on 1 night this week',
    );
    return '$_temp0';
  }

  @override
  String get allNightsLit => 'The lights stayed on every night this week';

  @override
  String diffLess(String amount) {
    return '$amount less than last week';
  }

  @override
  String diffMore(String amount) {
    return '$amount more than last week';
  }

  @override
  String get diffSame => 'Same as last week';

  @override
  String get notifNightReminder =>
      'I gotta sleep.. but it\'s still too bright 😭';

  @override
  String get notifBillArrived => 'Last week\'s bill has arrived';

  @override
  String get notifMorningGreeting => 'Good morning, rise and shine!';

  @override
  String notifMorningGreetingNamed(String name) {
    return 'Good morning $name, rise and shine!';
  }

  @override
  String get settingsTitle => 'Settings';

  @override
  String get sectionNotifications => 'Notifications';

  @override
  String get pushSettings => 'Push Notifications';

  @override
  String get pushSettingsCaption => 'Todd wants to talk to you';

  @override
  String get pushSettingsTitle => 'Push Notifications';

  @override
  String get morningGreeting => 'Morning greeting';

  @override
  String get morningGreetingCaption => 'An hour after Todd wakes up';

  @override
  String get nightReminder => 'Unwind reminder';

  @override
  String get nightReminderCaption => '30 minutes before Todd\'s bedtime';

  @override
  String get todoReminder => 'Timed tasks';

  @override
  String get todoReminderCaption => '10 minutes before a task with a time';

  @override
  String get billNotification => 'Weekly Bill';

  @override
  String get billNotificationCaption =>
      'Last week\'s bill, every Monday morning';

  @override
  String get sectionFeel => 'Feel';

  @override
  String get sectionLight => 'Light color';

  @override
  String get lightAmber => 'Amber';

  @override
  String get lightSunset => 'Sunset';

  @override
  String get lightRose => 'Rose';

  @override
  String get lightLavender => 'Lavender';

  @override
  String get lightSky => 'Sky';

  @override
  String get lightMint => 'Mint';

  @override
  String get lightMoon => 'Moonlight';

  @override
  String get haptics => 'Haptics';

  @override
  String get sectionDay => 'Todd\'s day';

  @override
  String get wakeTime => 'Wake-up time';

  @override
  String get wakeTimeCaption => 'A new day begins when Todd wakes up';

  @override
  String get bedtime => 'Bedtime';

  @override
  String get bedtimeCaption => 'Todd needs the lights out by then';

  @override
  String hourLabel(int hour) {
    return '$hour:00';
  }

  @override
  String get sectionLanguage => 'Language';

  @override
  String get language => 'Language';

  @override
  String get sectionData => 'Data';

  @override
  String get eraseData => 'Erase all data';

  @override
  String get eraseDataCaption => 'Erases every task and record';

  @override
  String get eraseDataDialogBody =>
      'Every task and record will be erased. This can\'t be undone.';

  @override
  String get erase => 'Erase';

  @override
  String get fullResetDev => 'Full reset (dev)';

  @override
  String get fullResetDevCaption =>
      'Erases everything including settings, back to first run';

  @override
  String get obNext => 'Next';

  @override
  String get obHelloSleepy => 'Hi, I\'m To..d..';

  @override
  String get obHelloAwake => 'Oh hey! I\'m Todd';

  @override
  String get obHelloAwakeBody =>
      'Sorry about that —\nI\'m a bit of a sleepyhead..';

  @override
  String get obWakeToastTitle => 'Todd dozed off!';

  @override
  String get obWakeToastBody => 'Tap to wake Todd up';

  @override
  String get obWakeAction => 'Wake Todd';

  @override
  String get obNightTitle => 'I need to sleep but..';

  @override
  String get obNightBody =>
      'The light is too bright.\nCan you check off the to-dos?';

  @override
  String get obLightsDone => 'That\'s perfect!';

  @override
  String get obLightsDoneBody =>
      'I can finally get some\ngood sleep tonight. Thanks!';

  @override
  String get obDummy1 => 'Drink 2L of water';

  @override
  String get obDummy2 => 'Go to the gym';

  @override
  String get obDummy3 => 'Read for 30 minutes';

  @override
  String get obBillTitle => 'Every Monday,\nyour bill arrives';

  @override
  String get obBillBody => 'Let\'s see how much light\nyou kept on last week.';

  @override
  String get obBillOnMe => 'Don\'t worry — it\'s on me!';

  @override
  String get obQuestionsTitle => 'Now I got a few\nquick questions!';

  @override
  String get obQuestionsBody => 'Let\'s sync our daily routine.';

  @override
  String get obHabitsTitle => 'Do you have any daily routine?';

  @override
  String get obHabitsBody => 'Or something you\'re planning to.';

  @override
  String get obHabitsHint => 'e.g. Stretch for 5 minutes';

  @override
  String get obHabitsNone => 'Not yet';

  @override
  String get obHabitsDefault => 'Drink 2L of water';

  @override
  String get obReadyTitle => 'Ready to make\nevery day count\nwith me?';

  @override
  String get obReadyNo => '🥱 Not really';

  @override
  String get obReadySomewhat => '🙂 Kind of';

  @override
  String get obReadyYes => '🤩 Yes, can\'t wait!';

  @override
  String get obSleepQTitle => 'When do you usually go to bed?';

  @override
  String get obSleepQBody => 'Btw, I unwind quite early in the evening.';

  @override
  String obSleepQResult(String time) {
    return 'You can change this later';
  }

  @override
  String get obWakeQTitle => 'When do you usually wake up?';

  @override
  String get obWakeQBody => 'I\'m an early-riser, just so you know.';

  @override
  String obWakeQResult(String time) {
    return 'You can change this later';
  }

  @override
  String get obScheduleTitle => 'Got it!\nThis is my day.';

  @override
  String obScheduleBody(String bed, String wake) {
    return 'Unwind at $bed, get up at $wake.';
  }

  @override
  String get obNameTitle => 'What should I call you?';

  @override
  String get obNameHint => 'Your name';

  @override
  String get obBegin => 'Let\'s begin';

  @override
  String obGreeting(String name) {
    return 'You\'re all set, $name!';
  }

  @override
  String get obGreetingNoName => 'You\'re all set!';

  @override
  String get obWidgetTitle => 'Oh, one last thing...';

  @override
  String get obWidgetBody =>
      'Install Todd widget.\nYou won\'t forget your checklist.';

  @override
  String get obWidgetStep1 => 'Go to the Home Screen';

  @override
  String get obWidgetStep2 => 'Touch and hold an empty spot';

  @override
  String get obWidgetStep3 => 'Tap \'Add Widget\', then Todd';

  @override
  String get obWidgetCta => 'Got it!';

  @override
  String get obWidgetPillLeft => 'left';

  @override
  String get m0Reset => 'Experience again from the start (M0 test)';

  @override
  String get autoDeferTitle => 'Postpone automatically';

  @override
  String get autoDeferSubtitle => 'If not done today, moves to tomorrow';

  @override
  String get taskTime => 'Time';

  @override
  String get taskTimeNone => 'Any time';

  @override
  String get todoReminderBody =>
      'A gentle reminder — this light is due in 10 minutes';
}
