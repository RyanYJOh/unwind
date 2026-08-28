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

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Todd'**
  String get appName;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @emptyRoomTitle.
  ///
  /// In en, this message translates to:
  /// **'No to-do items'**
  String get emptyRoomTitle;

  /// No description provided for @emptyRoomSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Wait.. the light can\'t be turned off?'**
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

  /// No description provided for @pullCordCoach.
  ///
  /// In en, this message translates to:
  /// **'Pull the handle all the way down.'**
  String get pullCordCoach;

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

  /// No description provided for @weekIncompleteOnly.
  ///
  /// In en, this message translates to:
  /// **'Incomplete tasks'**
  String get weekIncompleteOnly;

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

  /// No description provided for @addMemo.
  ///
  /// In en, this message translates to:
  /// **'Add a note'**
  String get addMemo;

  /// No description provided for @toddSleepingNotice.
  ///
  /// In en, this message translates to:
  /// **'Todd\'s asleep. This will go in tomorrow'**
  String get toddSleepingNotice;

  /// No description provided for @toddPokeLabel.
  ///
  /// In en, this message translates to:
  /// **'Todd'**
  String get toddPokeLabel;

  /// No description provided for @toddAway.
  ///
  /// In en, this message translates to:
  /// **'I\'m in today\'s room'**
  String get toddAway;

  /// No description provided for @toastTaskDeleted.
  ///
  /// In en, this message translates to:
  /// **'To-do deleted'**
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
  /// **'Weekly Electric Bill'**
  String get billTitle;

  /// No description provided for @billTasksClosed.
  ///
  /// In en, this message translates to:
  /// **'{done} / {total}'**
  String billTasksClosed(int done, int total);

  /// No description provided for @billTasksCaption.
  ///
  /// In en, this message translates to:
  /// **'tasks closed last week'**
  String get billTasksCaption;

  /// No description provided for @billTotalCaption.
  ///
  /// In en, this message translates to:
  /// **'{kwh} kWh left burning overnight'**
  String billTotalCaption(String kwh);

  /// No description provided for @wonAmount.
  ///
  /// In en, this message translates to:
  /// **'₩{amount}'**
  String wonAmount(String amount);

  /// No description provided for @sleepDeep.
  ///
  /// In en, this message translates to:
  /// **'Todd had perfect sleep'**
  String get sleepDeep;

  /// No description provided for @sleepWell.
  ///
  /// In en, this message translates to:
  /// **'Todd slept fine'**
  String get sleepWell;

  /// No description provided for @sleepTossed.
  ///
  /// In en, this message translates to:
  /// **'Todd tossed and turned a little'**
  String get sleepTossed;

  /// No description provided for @sleepBarely.
  ///
  /// In en, this message translates to:
  /// **'Todd barely closed an eye'**
  String get sleepBarely;

  /// No description provided for @sleepNone.
  ///
  /// In en, this message translates to:
  /// **'Todd stayed awake all night'**
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
  /// **'I gotta sleep.. but it\'s still too bright 😭'**
  String get notifNightReminder;

  /// No description provided for @notifBillArrived.
  ///
  /// In en, this message translates to:
  /// **'Last week\'s bill has arrived'**
  String get notifBillArrived;

  /// No description provided for @notifMorningGreeting.
  ///
  /// In en, this message translates to:
  /// **'Good morning, rise and shine!'**
  String get notifMorningGreeting;

  /// No description provided for @notifMorningGreetingNamed.
  ///
  /// In en, this message translates to:
  /// **'Good morning {name}, rise and shine!'**
  String notifMorningGreetingNamed(String name);

  /// No description provided for @notifMorningGreetingCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Rise and shine! Let’s smash 1 task today 💪} other{Rise and shine! Let’s smash {count} tasks today 💪}}'**
  String notifMorningGreetingCount(int count);

  /// No description provided for @widgetNudgeTitle.
  ///
  /// In en, this message translates to:
  /// **'Try Todd as a widget!'**
  String get widgetNudgeTitle;

  /// No description provided for @widgetNudgeBody.
  ///
  /// In en, this message translates to:
  /// **'Long-press your Home Screen to add the widget 👻'**
  String get widgetNudgeBody;

  /// No description provided for @notifPermissionTitle.
  ///
  /// In en, this message translates to:
  /// **'Turn on notifications?'**
  String get notifPermissionTitle;

  /// No description provided for @notifPermissionBody.
  ///
  /// In en, this message translates to:
  /// **'Notifications are off on this device, so I can\'t nudge you at the time you set.'**
  String get notifPermissionBody;

  /// No description provided for @notifPermissionConfirm.
  ///
  /// In en, this message translates to:
  /// **'Allow notifications'**
  String get notifPermissionConfirm;

  /// No description provided for @notifPermissionLater.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get notifPermissionLater;

  /// No description provided for @notifPermissionSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'I\'ll take you to Settings!'**
  String get notifPermissionSettingsTitle;

  /// No description provided for @notifPermissionSettingsBody.
  ///
  /// In en, this message translates to:
  /// **'My notifications are switched off there. Flip them on, and I\'ll nudge you right on time ✨'**
  String get notifPermissionSettingsBody;

  /// No description provided for @notifPermissionOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get notifPermissionOpenSettings;

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

  /// No description provided for @pushSettings.
  ///
  /// In en, this message translates to:
  /// **'Push Notifications'**
  String get pushSettings;

  /// No description provided for @pushSettingsCaption.
  ///
  /// In en, this message translates to:
  /// **'Todd wants to talk to you'**
  String get pushSettingsCaption;

  /// No description provided for @pushSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Push Notifications'**
  String get pushSettingsTitle;

  /// No description provided for @morningGreeting.
  ///
  /// In en, this message translates to:
  /// **'Morning greeting'**
  String get morningGreeting;

  /// No description provided for @morningGreetingCaption.
  ///
  /// In en, this message translates to:
  /// **'An hour after Todd wakes up'**
  String get morningGreetingCaption;

  /// No description provided for @nightReminder.
  ///
  /// In en, this message translates to:
  /// **'Unwind reminder'**
  String get nightReminder;

  /// No description provided for @nightReminderCaption.
  ///
  /// In en, this message translates to:
  /// **'30 minutes before Todd\'s bedtime'**
  String get nightReminderCaption;

  /// No description provided for @todoReminder.
  ///
  /// In en, this message translates to:
  /// **'Timed tasks'**
  String get todoReminder;

  /// No description provided for @todoReminderCaption.
  ///
  /// In en, this message translates to:
  /// **'10 minutes before a task with a time'**
  String get todoReminderCaption;

  /// No description provided for @billNotification.
  ///
  /// In en, this message translates to:
  /// **'Weekly Bill'**
  String get billNotification;

  /// No description provided for @billNotificationCaption.
  ///
  /// In en, this message translates to:
  /// **'Last week\'s bill, every Monday morning'**
  String get billNotificationCaption;

  /// No description provided for @sectionFeel.
  ///
  /// In en, this message translates to:
  /// **'Feel'**
  String get sectionFeel;

  /// No description provided for @sectionLight.
  ///
  /// In en, this message translates to:
  /// **'Light color'**
  String get sectionLight;

  /// No description provided for @calendarHeader.
  ///
  /// In en, this message translates to:
  /// **'{month} {year}'**
  String calendarHeader(String month, String year);

  /// No description provided for @plusTitle.
  ///
  /// In en, this message translates to:
  /// **'TODD PLUS'**
  String get plusTitle;

  /// No description provided for @plusHeroTitle.
  ///
  /// In en, this message translates to:
  /// **'Wanna get\na little closer?'**
  String get plusHeroTitle;

  /// No description provided for @plusHeroThanks.
  ///
  /// In en, this message translates to:
  /// **'Yay!\nWe\'re a team now'**
  String get plusHeroThanks;

  /// No description provided for @plusFeatureColors.
  ///
  /// In en, this message translates to:
  /// **'All 7 room light colors'**
  String get plusFeatureColors;

  /// No description provided for @plusFeatureColorsCaption.
  ///
  /// In en, this message translates to:
  /// **'Tap one — try it right now 👇'**
  String get plusFeatureColorsCaption;

  /// No description provided for @plusFeatureRecurrence.
  ///
  /// In en, this message translates to:
  /// **'Unlimited repeating to-dos'**
  String get plusFeatureRecurrence;

  /// No description provided for @plusFeatureRecurrenceCaption.
  ///
  /// In en, this message translates to:
  /// **'However many habits you keep'**
  String get plusFeatureRecurrenceCaption;

  /// No description provided for @plusFeatureMore.
  ///
  /// In en, this message translates to:
  /// **'…and many more to come!'**
  String get plusFeatureMore;

  /// No description provided for @plusMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get plusMonthly;

  /// No description provided for @plusMonthlyPrice.
  ///
  /// In en, this message translates to:
  /// **'\$3.99'**
  String get plusMonthlyPrice;

  /// No description provided for @plusMonthlyCaption.
  ///
  /// In en, this message translates to:
  /// **'Billed monthly'**
  String get plusMonthlyCaption;

  /// No description provided for @plusYearly.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get plusYearly;

  /// No description provided for @plusYearlyPrice.
  ///
  /// In en, this message translates to:
  /// **'\$23.99'**
  String get plusYearlyPrice;

  /// No description provided for @plusYearlyCaption.
  ///
  /// In en, this message translates to:
  /// **'≈ \$2 a month'**
  String get plusYearlyCaption;

  /// No description provided for @plusLifetime.
  ///
  /// In en, this message translates to:
  /// **'Lifetime'**
  String get plusLifetime;

  /// No description provided for @plusLifetimePrice.
  ///
  /// In en, this message translates to:
  /// **'\$59.99'**
  String get plusLifetimePrice;

  /// No description provided for @plusLifetimeCaption.
  ///
  /// In en, this message translates to:
  /// **'Pay once, keep forever'**
  String get plusLifetimeCaption;

  /// No description provided for @plusBest.
  ///
  /// In en, this message translates to:
  /// **'BEST'**
  String get plusBest;

  /// No description provided for @plusCta.
  ///
  /// In en, this message translates to:
  /// **'Join Todd'**
  String get plusCta;

  /// No description provided for @plusCancelNote.
  ///
  /// In en, this message translates to:
  /// **'Cancel anytime'**
  String get plusCancelNote;

  /// No description provided for @plusSettingsCaption.
  ///
  /// In en, this message translates to:
  /// **'Get closer with Todd'**
  String get plusSettingsCaption;

  /// No description provided for @plusSettingsActive.
  ///
  /// In en, this message translates to:
  /// **'In it together 💛'**
  String get plusSettingsActive;

  /// No description provided for @lightAmber.
  ///
  /// In en, this message translates to:
  /// **'Amber'**
  String get lightAmber;

  /// No description provided for @lightSunset.
  ///
  /// In en, this message translates to:
  /// **'Sunset'**
  String get lightSunset;

  /// No description provided for @lightRose.
  ///
  /// In en, this message translates to:
  /// **'Rose'**
  String get lightRose;

  /// No description provided for @lightLavender.
  ///
  /// In en, this message translates to:
  /// **'Lavender'**
  String get lightLavender;

  /// No description provided for @lightSky.
  ///
  /// In en, this message translates to:
  /// **'Sky'**
  String get lightSky;

  /// No description provided for @lightMint.
  ///
  /// In en, this message translates to:
  /// **'Mint'**
  String get lightMint;

  /// No description provided for @lightMoon.
  ///
  /// In en, this message translates to:
  /// **'Moonlight'**
  String get lightMoon;

  /// No description provided for @haptics.
  ///
  /// In en, this message translates to:
  /// **'Haptics'**
  String get haptics;

  /// No description provided for @sectionDay.
  ///
  /// In en, this message translates to:
  /// **'Your day'**
  String get sectionDay;

  /// No description provided for @wakeTime.
  ///
  /// In en, this message translates to:
  /// **'Wake-up time'**
  String get wakeTime;

  /// No description provided for @wakeTimeCaption.
  ///
  /// In en, this message translates to:
  /// **'Todd wakes up at {time}'**
  String wakeTimeCaption(String time);

  /// No description provided for @bedtime.
  ///
  /// In en, this message translates to:
  /// **'Bedtime'**
  String get bedtime;

  /// No description provided for @bedtimeCaption.
  ///
  /// In en, this message translates to:
  /// **'Todd goes to sleep at {time}'**
  String bedtimeCaption(String time);

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

  /// No description provided for @obNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get obNext;

  /// No description provided for @obHelloSleepy.
  ///
  /// In en, this message translates to:
  /// **'Hi, I\'m To..d..'**
  String get obHelloSleepy;

  /// No description provided for @obHelloAwake.
  ///
  /// In en, this message translates to:
  /// **'Oh hey! I\'m Todd'**
  String get obHelloAwake;

  /// No description provided for @obHelloAwakeBody.
  ///
  /// In en, this message translates to:
  /// **'Sorry about that —\nI\'m a bit of a sleepyhead..'**
  String get obHelloAwakeBody;

  /// No description provided for @obWakeToastTitle.
  ///
  /// In en, this message translates to:
  /// **'Todd dozed off!'**
  String get obWakeToastTitle;

  /// No description provided for @obWakeToastBody.
  ///
  /// In en, this message translates to:
  /// **'Tap to wake Todd up'**
  String get obWakeToastBody;

  /// No description provided for @obWakeMoreToast.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Almost awake — just 1 more tap!} other{Almost awake — {count} more taps!}}'**
  String obWakeMoreToast(int count);

  /// No description provided for @obWakeAction.
  ///
  /// In en, this message translates to:
  /// **'Wake Todd'**
  String get obWakeAction;

  /// No description provided for @obNightTitle.
  ///
  /// In en, this message translates to:
  /// **'I gotta sleep but..'**
  String get obNightTitle;

  /// No description provided for @obNightBody.
  ///
  /// In en, this message translates to:
  /// **'The light is too bright.\nCan you check off the to-dos?'**
  String get obNightBody;

  /// No description provided for @obLightsDone.
  ///
  /// In en, this message translates to:
  /// **'That\'s perfect!'**
  String get obLightsDone;

  /// No description provided for @obLightsDoneBody.
  ///
  /// In en, this message translates to:
  /// **'I can finally get some\ngood sleep tonight. Thanks!'**
  String get obLightsDoneBody;

  /// No description provided for @obDummy1.
  ///
  /// In en, this message translates to:
  /// **'Drink 2L of water'**
  String get obDummy1;

  /// No description provided for @obDummy2.
  ///
  /// In en, this message translates to:
  /// **'Go to the gym'**
  String get obDummy2;

  /// No description provided for @obDummy3.
  ///
  /// In en, this message translates to:
  /// **'Read for 30 minutes'**
  String get obDummy3;

  /// No description provided for @obBillTitle.
  ///
  /// In en, this message translates to:
  /// **'Every Monday,\nyour bill arrives'**
  String get obBillTitle;

  /// No description provided for @obBillBody.
  ///
  /// In en, this message translates to:
  /// **'Let\'s see how much light\nyou kept on last week.'**
  String get obBillBody;

  /// No description provided for @obBillOnMe.
  ///
  /// In en, this message translates to:
  /// **'Don\'t worry — it\'s on me!'**
  String get obBillOnMe;

  /// No description provided for @obQuestionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Now I got a few\nquick questions!'**
  String get obQuestionsTitle;

  /// No description provided for @obQuestionsBody.
  ///
  /// In en, this message translates to:
  /// **'Let\'s sync our daily routine.'**
  String get obQuestionsBody;

  /// No description provided for @obHabitsTitle.
  ///
  /// In en, this message translates to:
  /// **'Do you have any daily routine?'**
  String get obHabitsTitle;

  /// No description provided for @obHabitsBody.
  ///
  /// In en, this message translates to:
  /// **'Or something you\'re planning to.'**
  String get obHabitsBody;

  /// No description provided for @obHabitsHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Stretch for 5 minutes'**
  String get obHabitsHint;

  /// No description provided for @obHabitsNone.
  ///
  /// In en, this message translates to:
  /// **'Not yet'**
  String get obHabitsNone;

  /// No description provided for @obHabitsDefault.
  ///
  /// In en, this message translates to:
  /// **'Drink 2L of water'**
  String get obHabitsDefault;

  /// No description provided for @obReadyTitle.
  ///
  /// In en, this message translates to:
  /// **'Ready to make\nevery day count\nwith me?'**
  String get obReadyTitle;

  /// No description provided for @obReadyNo.
  ///
  /// In en, this message translates to:
  /// **'🥱 Not really'**
  String get obReadyNo;

  /// No description provided for @obReadySomewhat.
  ///
  /// In en, this message translates to:
  /// **'🙂 Kind of'**
  String get obReadySomewhat;

  /// No description provided for @obReadyYes.
  ///
  /// In en, this message translates to:
  /// **'🤩 Yes, can\'t wait!'**
  String get obReadyYes;

  /// No description provided for @obSleepQTitle.
  ///
  /// In en, this message translates to:
  /// **'When do you usually go to bed?'**
  String get obSleepQTitle;

  /// No description provided for @obSleepQBody.
  ///
  /// In en, this message translates to:
  /// **'Btw, I unwind quite early in the evening.'**
  String get obSleepQBody;

  /// No description provided for @obSleepQResult.
  ///
  /// In en, this message translates to:
  /// **'You can change this later'**
  String obSleepQResult(String time);

  /// No description provided for @obWakeQTitle.
  ///
  /// In en, this message translates to:
  /// **'When do you usually wake up?'**
  String get obWakeQTitle;

  /// No description provided for @obWakeQBody.
  ///
  /// In en, this message translates to:
  /// **'I\'m an early-riser, just so you know.'**
  String get obWakeQBody;

  /// No description provided for @obWakeQResult.
  ///
  /// In en, this message translates to:
  /// **'You can change this later'**
  String obWakeQResult(String time);

  /// No description provided for @obScheduleTitle.
  ///
  /// In en, this message translates to:
  /// **'Got it!\nThis is my day.'**
  String get obScheduleTitle;

  /// No description provided for @obScheduleBody.
  ///
  /// In en, this message translates to:
  /// **'Unwind at {bed}, get up at {wake}.'**
  String obScheduleBody(String bed, String wake);

  /// No description provided for @obNameTitle.
  ///
  /// In en, this message translates to:
  /// **'What should I call you?'**
  String get obNameTitle;

  /// No description provided for @obNameHint.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get obNameHint;

  /// No description provided for @obBegin.
  ///
  /// In en, this message translates to:
  /// **'Let\'s begin'**
  String get obBegin;

  /// No description provided for @obGreeting.
  ///
  /// In en, this message translates to:
  /// **'You\'re all set, {name}!'**
  String obGreeting(String name);

  /// No description provided for @obGreetingNoName.
  ///
  /// In en, this message translates to:
  /// **'You\'re all set!'**
  String get obGreetingNoName;

  /// No description provided for @obNameToddCoincidence.
  ///
  /// In en, this message translates to:
  /// **'(What are the odds.. Todd?)'**
  String get obNameToddCoincidence;

  /// No description provided for @obWidgetTitle.
  ///
  /// In en, this message translates to:
  /// **'Oh, one last thing...'**
  String get obWidgetTitle;

  /// No description provided for @obWidgetBody.
  ///
  /// In en, this message translates to:
  /// **'Install Todd widget.\nYou won\'t forget your checklist.'**
  String get obWidgetBody;

  /// No description provided for @obWidgetStep1.
  ///
  /// In en, this message translates to:
  /// **'Go to the Home Screen'**
  String get obWidgetStep1;

  /// No description provided for @obWidgetStep2.
  ///
  /// In en, this message translates to:
  /// **'Touch and hold an empty spot'**
  String get obWidgetStep2;

  /// No description provided for @obWidgetStep3.
  ///
  /// In en, this message translates to:
  /// **'Tap \'Add Widget\', then Todd'**
  String get obWidgetStep3;

  /// No description provided for @obWidgetCta.
  ///
  /// In en, this message translates to:
  /// **'Got it!'**
  String get obWidgetCta;

  /// No description provided for @obWidgetPillLeft.
  ///
  /// In en, this message translates to:
  /// **'left'**
  String get obWidgetPillLeft;

  /// No description provided for @m0Reset.
  ///
  /// In en, this message translates to:
  /// **'Experience again from the start (M0 test)'**
  String get m0Reset;

  /// No description provided for @autoDeferTitle.
  ///
  /// In en, this message translates to:
  /// **'Postpone automatically'**
  String get autoDeferTitle;

  /// No description provided for @autoDeferSubtitle.
  ///
  /// In en, this message translates to:
  /// **'If not done today, moves to tomorrow'**
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

  /// No description provided for @notifTimedTitle.
  ///
  /// In en, this message translates to:
  /// **'You got 10 minutes'**
  String get notifTimedTitle;

  /// No description provided for @notifTimedBody.
  ///
  /// In en, this message translates to:
  /// **'...for \"{title}\"'**
  String notifTimedBody(String title);

  /// No description provided for @notifNightReminderTitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 more to-do left!} other{{count} more to-dos left!}}'**
  String notifNightReminderTitle(int count);
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
