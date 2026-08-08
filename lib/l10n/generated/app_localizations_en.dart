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
  String get memoHint => 'Note';

  @override
  String get addMemo => 'Add a note';

  @override
  String get lumiSleepingNotice =>
      'Lumi is asleep. This will go in tomorrow\'s room';

  @override
  String get toastTaskAdded => 'A new light is on';

  @override
  String get dateToday => 'Today';

  @override
  String get dateTomorrow => 'Tomorrow';

  @override
  String get dateDayAfter => 'In 2 days';

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
  String get weekdaysShort => 'Mon,Tue,Wed,Thu,Fri,Sat,Sun';

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
  String get notifNightReminder => 'Lumi is still awake';

  @override
  String get notifBillArrived => 'Last week\'s bill has arrived';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get sectionNotifications => 'Notifications';

  @override
  String get nightReminder => 'Night reminder';

  @override
  String get nightReminderCaption => 'A gentle note when Lumi is still awake';

  @override
  String get reminderTime => 'Reminder time';

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
  String get sectionDay => 'Day';

  @override
  String get dayStart => 'Day starts at';

  @override
  String get dayStartCaption => 'Until then, it\'s still yesterday\'s room';

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
  String get onboardTitle => 'Lumi wants to sleep';

  @override
  String get onboardBody =>
      'Each task is a lamp.\nFinish one, and the room gets a little darker.\nWhen the last light goes out, Lumi falls asleep.';

  @override
  String get onboardGo => 'Go turn off the lights';

  @override
  String get onboardTransition => 'Now, let\'s write down today\'s real tasks';

  @override
  String get onboardStart => 'Start writing';

  @override
  String get onboardSample1 => 'Reply to today\'s email';

  @override
  String get onboardSample2 => 'Return the borrowed book';

  @override
  String get onboardSample3 => 'A 20-minute evening walk';

  @override
  String get m0Reset => 'Experience again from the start (M0 test)';
}
