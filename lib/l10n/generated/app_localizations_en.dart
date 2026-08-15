// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get today => 'Today';

  @override
  String get emptyRoomTitle => 'No lights to keep on today';

  @override
  String get emptyRoomSubtitle =>
      'Write down a task, and a light turns on in this room';

  @override
  String get billBadge => 'Bill';

  @override
  String get addTaskLabel => 'Add a task';

  @override
  String get endDayLabel => 'End the day';

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
  String get lumiSleepingNotice =>
      'Lumi is asleep. This will go in tomorrow\'s room';

  @override
  String get lumiPokeLabel => 'Lumi';

  @override
  String get lumiAway => 'Lumi is in today\'s room';

  @override
  String get toastTaskDeleted => 'Taken out of the room';

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
  String get billTitle => 'Unwind Electric Bill';

  @override
  String billTotalCaption(String kwh, String fee) {
    return 'Total $kwh kWh · includes $fee base fee';
  }

  @override
  String wonAmount(String amount) {
    return '₩$amount';
  }

  @override
  String get sleepDeep => 'Lumi slept deeply';

  @override
  String get sleepWell => 'Lumi slept well';

  @override
  String get sleepTossed => 'Lumi tossed and turned a little';

  @override
  String get sleepBarely => 'Lumi barely closed an eye';

  @override
  String get sleepNone => 'Lumi stayed awake all night';

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
      'It\'s Lumi\'s bedtime — the lights are still on';

  @override
  String get notifBillArrived => 'Last week\'s bill has arrived';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get sectionNotifications => 'Notifications';

  @override
  String get nightReminder => 'Bedtime reminder';

  @override
  String get nightReminderCaption =>
      'A gentle note at bedtime if lights are still on';

  @override
  String get billNotification => 'Bill arrival';

  @override
  String get billNotificationCaption =>
      'Your last week\'s bill, every Monday morning';

  @override
  String get sectionFeel => 'Feel';

  @override
  String get sound => 'Sound';

  @override
  String get haptics => 'Haptics';

  @override
  String get sectionDay => 'Lumi\'s day';

  @override
  String get wakeTime => 'Wake-up time';

  @override
  String get wakeTimeCaption => 'A new day begins when Lumi wakes up';

  @override
  String get bedtime => 'Bedtime';

  @override
  String get bedtimeCaption => 'Lumi needs the lights out by then';

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
  String get obWelcomeTitle => 'Get things done with Lumi';

  @override
  String get obWelcomeBody =>
      'This is Lumi — a little ghost who lives in your room. Finishing your day is what lets Lumi sleep.';

  @override
  String get obNightTitle => 'At night, Lumi needs to sleep';

  @override
  String get obNightBody =>
      'But the lights are still on — far too bright to sleep in. Poor Lumi.';

  @override
  String get obLightsTitle => 'Each task is a lamp';

  @override
  String get obLightsBody =>
      'Finish a task, flip its switch. Try turning them all off.';

  @override
  String get obLightsDone => 'All lights out — sweet dreams, Lumi';

  @override
  String get obDummy1 => 'Drink 2L of water';

  @override
  String get obDummy2 => 'Work out';

  @override
  String get obDummy3 => 'Read for 30 minutes';

  @override
  String get obBillTitle => 'Every Monday, a bill arrives';

  @override
  String get obBillBody =>
      'The lights you leave on burn electricity all night. Tap the bill to peek at a receipt.';

  @override
  String get obQuestionsTitle => 'Now, a few quick questions';

  @override
  String get obQuestionsBody => 'So Lumi can live around your day.';

  @override
  String get obHabitsTitle => 'Is there something you do every day?';

  @override
  String get obHabitsBody =>
      'Add it once, and a lamp will be waiting for you every morning.';

  @override
  String get obHabitsHint => 'e.g. Stretch for 5 minutes';

  @override
  String get obHabitsNone => 'Not yet';

  @override
  String get obHabitsDefault => 'Drink 2L of water';

  @override
  String get obSleepQTitle => 'When do you usually fall asleep?';

  @override
  String get obSleepQBody =>
      'Sleepyhead Lumi dozes off three hours before you.';

  @override
  String obSleepQResult(String time) {
    return 'So Lumi\'s bedtime will be $time';
  }

  @override
  String get obWakeQTitle => 'When do you usually wake up?';

  @override
  String get obWakeQBody => 'Lumi gets up an hour earlier to open up the day.';

  @override
  String obWakeQResult(String time) {
    return 'So Lumi will rise at $time';
  }

  @override
  String get obScheduleTitle => 'Lumi\'s day is set';

  @override
  String obScheduleBody(String bed, String wake) {
    return 'Asleep at $bed, up at $wake — always a little ahead of you.';
  }

  @override
  String get obNameTitle => 'What should Lumi call you?';

  @override
  String get obNameHint => 'Your name';

  @override
  String get obSkip => 'Skip';

  @override
  String get obBegin => 'Let\'s begin';

  @override
  String obGreeting(String name) {
    return 'Nice to meet you, $name!';
  }

  @override
  String get obGreetingNoName => 'Nice to meet you!';

  @override
  String get m0Reset => 'Experience again from the start (M0 test)';

  @override
  String get autoDeferTitle => 'Move to tomorrow automatically';

  @override
  String get autoDeferSubtitle =>
      'If it isn\'t done today, it moves to tomorrow\'s room';

  @override
  String get taskTime => 'Time';

  @override
  String get taskTimeNone => 'Any time';

  @override
  String get todoReminderBody =>
      'A gentle reminder — this light is due in 10 minutes';
}
