import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ko.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ko'),
  ];

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @emptyRoomTitle.
  ///
  /// In en, this message translates to:
  /// **'No lights to keep on today'**
  String get emptyRoomTitle;

  /// No description provided for @emptyRoomSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Write down a task, and a light turns on in this room'**
  String get emptyRoomSubtitle;

  /// No description provided for @billBadge.
  ///
  /// In en, this message translates to:
  /// **'Bill'**
  String get billBadge;

  /// No description provided for @addTaskLabel.
  ///
  /// In en, this message translates to:
  /// **'Add a task'**
  String get addTaskLabel;

  /// No description provided for @endDayLabel.
  ///
  /// In en, this message translates to:
  /// **'End the day'**
  String get endDayLabel;

  /// No description provided for @lampOn.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get lampOn;

  /// No description provided for @lampOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get lampOff;

  /// No description provided for @weekNumber.
  ///
  /// In en, this message translates to:
  /// **'Week {n}'**
  String weekNumber(int n);

  /// No description provided for @weekProgressLabel.
  ///
  /// In en, this message translates to:
  /// **'This week\'s progress'**
  String get weekProgressLabel;

  /// No description provided for @weekAllDone.
  ///
  /// In en, this message translates to:
  /// **'All done this week'**
  String get weekAllDone;

  /// No description provided for @weekEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing planned this week yet'**
  String get weekEmpty;

  /// No description provided for @addToDay.
  ///
  /// In en, this message translates to:
  /// **'Add to {day}'**
  String addToDay(String day);

  /// No description provided for @openDay.
  ///
  /// In en, this message translates to:
  /// **'Open {day}'**
  String openDay(String day);

  /// No description provided for @lastWeek.
  ///
  /// In en, this message translates to:
  /// **'Last week'**
  String get lastWeek;

  /// No description provided for @nextWeek.
  ///
  /// In en, this message translates to:
  /// **'Next week'**
  String get nextWeek;

  /// No description provided for @weekRange.
  ///
  /// In en, this message translates to:
  /// **'{from} – {to}'**
  String weekRange(String from, String to);

  /// No description provided for @thisWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get thisWeek;

  /// No description provided for @thisWeekLabel.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get thisWeekLabel;

  /// No description provided for @collapse.
  ///
  /// In en, this message translates to:
  /// **'Collapse'**
  String get collapse;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @deleteThisTask.
  ///
  /// In en, this message translates to:
  /// **'Delete only this task'**
  String get deleteThisTask;

  /// No description provided for @deleteFutureRecurring.
  ///
  /// In en, this message translates to:
  /// **'Delete this and all future repeats'**
  String get deleteFutureRecurring;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @taskHint.
  ///
  /// In en, this message translates to:
  /// **'Task'**
  String get taskHint;

  /// No description provided for @memoHint.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get memoHint;

  /// No description provided for @addMemo.
  ///
  /// In en, this message translates to:
  /// **'Add a note'**
  String get addMemo;

  /// No description provided for @lumiSleepingNotice.
  ///
  /// In en, this message translates to:
  /// **'Lumi is asleep. This will go in tomorrow\'s room'**
  String get lumiSleepingNotice;

  /// No description provided for @lumiPokeLabel.
  ///
  /// In en, this message translates to:
  /// **'Lumi'**
  String get lumiPokeLabel;

  /// No description provided for @toastTaskDeleted.
  ///
  /// In en, this message translates to:
  /// **'Taken out of the room'**
  String get toastTaskDeleted;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @toastTaskAdded.
  ///
  /// In en, this message translates to:
  /// **'A new light is on'**
  String get toastTaskAdded;

  /// No description provided for @dateToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get dateToday;

  /// No description provided for @dateTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get dateTomorrow;

  /// No description provided for @dateDayAfter.
  ///
  /// In en, this message translates to:
  /// **'In 2 days'**
  String get dateDayAfter;

  /// No description provided for @chooseDate.
  ///
  /// In en, this message translates to:
  /// **'Choose date'**
  String get chooseDate;

  /// No description provided for @repeatSection.
  ///
  /// In en, this message translates to:
  /// **'Repeat'**
  String get repeatSection;

  /// No description provided for @repeatNone.
  ///
  /// In en, this message translates to:
  /// **'No repeat'**
  String get repeatNone;

  /// No description provided for @repeatDaily.
  ///
  /// In en, this message translates to:
  /// **'Every day'**
  String get repeatDaily;

  /// No description provided for @repeatWeekdays.
  ///
  /// In en, this message translates to:
  /// **'Weekdays'**
  String get repeatWeekdays;

  /// No description provided for @repeatWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get repeatWeekly;

  /// No description provided for @repeatMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get repeatMonthly;

  /// No description provided for @repeatEveryWeekday.
  ///
  /// In en, this message translates to:
  /// **'Every {weekday}'**
  String repeatEveryWeekday(String weekday);

  /// No description provided for @repeatEveryMonthDay.
  ///
  /// In en, this message translates to:
  /// **'Every {day}'**
  String repeatEveryMonthDay(String day);

  /// No description provided for @weekdaysShort.
  ///
  /// In en, this message translates to:
  /// **'Mon,Tue,Wed,Thu,Fri,Sat,Sun'**
  String get weekdaysShort;

  /// No description provided for @weekdaysLong.
  ///
  /// In en, this message translates to:
  /// **'Monday,Tuesday,Wednesday,Thursday,Friday,Saturday,Sunday'**
  String get weekdaysLong;

  /// No description provided for @monthsShort.
  ///
  /// In en, this message translates to:
  /// **'Jan,Feb,Mar,Apr,May,Jun,Jul,Aug,Sep,Oct,Nov,Dec'**
  String get monthsShort;

  /// No description provided for @monthDay.
  ///
  /// In en, this message translates to:
  /// **'{monthName} {day}'**
  String monthDay(String monthName, int month, int day);

  /// No description provided for @billTitle.
  ///
  /// In en, this message translates to:
  /// **'Unwind Electric Bill'**
  String get billTitle;

  /// No description provided for @billTotalCaption.
  ///
  /// In en, this message translates to:
  /// **'Total {kwh} kWh · includes {fee} base fee'**
  String billTotalCaption(String kwh, String fee);

  /// No description provided for @wonAmount.
  ///
  /// In en, this message translates to:
  /// **'₩{amount}'**
  String wonAmount(String amount);

  /// No description provided for @sleepDeep.
  ///
  /// In en, this message translates to:
  /// **'Lumi slept deeply'**
  String get sleepDeep;

  /// No description provided for @sleepWell.
  ///
  /// In en, this message translates to:
  /// **'Lumi slept well'**
  String get sleepWell;

  /// No description provided for @sleepTossed.
  ///
  /// In en, this message translates to:
  /// **'Lumi tossed and turned a little'**
  String get sleepTossed;

  /// No description provided for @sleepBarely.
  ///
  /// In en, this message translates to:
  /// **'Lumi barely closed an eye'**
  String get sleepBarely;

  /// No description provided for @sleepNone.
  ///
  /// In en, this message translates to:
  /// **'Lumi stayed awake all night'**
  String get sleepNone;

  /// No description provided for @nightsOut.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{You turned the lights out on 1 night this week} other{You turned the lights out on {count} nights this week}}'**
  String nightsOut(int count);

  /// No description provided for @allNightsLit.
  ///
  /// In en, this message translates to:
  /// **'The lights stayed on every night this week'**
  String get allNightsLit;

  /// No description provided for @diffLess.
  ///
  /// In en, this message translates to:
  /// **'{amount} less than last week'**
  String diffLess(String amount);

  /// No description provided for @diffMore.
  ///
  /// In en, this message translates to:
  /// **'{amount} more than last week'**
  String diffMore(String amount);

  /// No description provided for @diffSame.
  ///
  /// In en, this message translates to:
  /// **'Same as last week'**
  String get diffSame;

  /// No description provided for @notifNightReminder.
  ///
  /// In en, this message translates to:
  /// **'Lumi is still awake'**
  String get notifNightReminder;

  /// No description provided for @notifBillArrived.
  ///
  /// In en, this message translates to:
  /// **'Last week\'s bill has arrived'**
  String get notifBillArrived;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @sectionNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get sectionNotifications;

  /// No description provided for @nightReminder.
  ///
  /// In en, this message translates to:
  /// **'Night reminder'**
  String get nightReminder;

  /// No description provided for @nightReminderCaption.
  ///
  /// In en, this message translates to:
  /// **'A gentle note when Lumi is still awake'**
  String get nightReminderCaption;

  /// No description provided for @reminderTime.
  ///
  /// In en, this message translates to:
  /// **'Reminder time'**
  String get reminderTime;

  /// No description provided for @billNotification.
  ///
  /// In en, this message translates to:
  /// **'Bill arrival'**
  String get billNotification;

  /// No description provided for @billNotificationCaption.
  ///
  /// In en, this message translates to:
  /// **'Your last week\'s bill, every Monday morning'**
  String get billNotificationCaption;

  /// No description provided for @sectionFeel.
  ///
  /// In en, this message translates to:
  /// **'Feel'**
  String get sectionFeel;

  /// No description provided for @sound.
  ///
  /// In en, this message translates to:
  /// **'Sound'**
  String get sound;

  /// No description provided for @haptics.
  ///
  /// In en, this message translates to:
  /// **'Haptics'**
  String get haptics;

  /// No description provided for @sectionDay.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get sectionDay;

  /// No description provided for @dayStart.
  ///
  /// In en, this message translates to:
  /// **'Day starts at'**
  String get dayStart;

  /// No description provided for @dayStartCaption.
  ///
  /// In en, this message translates to:
  /// **'Until then, it\'s still yesterday\'s room'**
  String get dayStartCaption;

  /// No description provided for @hourLabel.
  ///
  /// In en, this message translates to:
  /// **'{hour}:00'**
  String hourLabel(int hour);

  /// No description provided for @sectionLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get sectionLanguage;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @sectionData.
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get sectionData;

  /// No description provided for @eraseData.
  ///
  /// In en, this message translates to:
  /// **'Erase all data'**
  String get eraseData;

  /// No description provided for @eraseDataCaption.
  ///
  /// In en, this message translates to:
  /// **'Erases every task and record'**
  String get eraseDataCaption;

  /// No description provided for @eraseDataDialogBody.
  ///
  /// In en, this message translates to:
  /// **'Every task and record will be erased. This can\'t be undone.'**
  String get eraseDataDialogBody;

  /// No description provided for @erase.
  ///
  /// In en, this message translates to:
  /// **'Erase'**
  String get erase;

  /// No description provided for @fullResetDev.
  ///
  /// In en, this message translates to:
  /// **'Full reset (dev)'**
  String get fullResetDev;

  /// No description provided for @fullResetDevCaption.
  ///
  /// In en, this message translates to:
  /// **'Erases everything including settings, back to first run'**
  String get fullResetDevCaption;

  /// No description provided for @onboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Lumi wants to sleep'**
  String get onboardTitle;

  /// No description provided for @onboardBody.
  ///
  /// In en, this message translates to:
  /// **'Each task is a lamp.\nFinish one, and the room gets a little darker.\nWhen the last light goes out, Lumi falls asleep.'**
  String get onboardBody;

  /// No description provided for @onboardGo.
  ///
  /// In en, this message translates to:
  /// **'Go turn off the lights'**
  String get onboardGo;

  /// No description provided for @onboardTransition.
  ///
  /// In en, this message translates to:
  /// **'Now, let\'s write down today\'s real tasks'**
  String get onboardTransition;

  /// No description provided for @onboardStart.
  ///
  /// In en, this message translates to:
  /// **'Start writing'**
  String get onboardStart;

  /// No description provided for @onboardSample1.
  ///
  /// In en, this message translates to:
  /// **'Reply to today\'s email'**
  String get onboardSample1;

  /// No description provided for @onboardSample2.
  ///
  /// In en, this message translates to:
  /// **'Return the borrowed book'**
  String get onboardSample2;

  /// No description provided for @onboardSample3.
  ///
  /// In en, this message translates to:
  /// **'A 20-minute evening walk'**
  String get onboardSample3;

  /// No description provided for @m0Reset.
  ///
  /// In en, this message translates to:
  /// **'Experience again from the start (M0 test)'**
  String get m0Reset;

  /// No description provided for @autoDeferTitle.
  ///
  /// In en, this message translates to:
  /// **'Move to tomorrow automatically'**
  String get autoDeferTitle;

  /// No description provided for @autoDeferSubtitle.
  ///
  /// In en, this message translates to:
  /// **'If it isn\'t done today, it moves to tomorrow\'s room'**
  String get autoDeferSubtitle;

  /// No description provided for @taskTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get taskTime;

  /// No description provided for @taskTimeNone.
  ///
  /// In en, this message translates to:
  /// **'Any time'**
  String get taskTimeNone;

  /// No description provided for @todoReminderBody.
  ///
  /// In en, this message translates to:
  /// **'A gentle reminder — this light is due in 10 minutes'**
  String get todoReminderBody;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ko'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ko':
      return AppLocalizationsKo();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
