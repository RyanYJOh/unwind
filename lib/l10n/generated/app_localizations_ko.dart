// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get today => '오늘';

  @override
  String get emptyRoomTitle => '오늘은 켜둘 불이 없어요';

  @override
  String get emptyRoomSubtitle => '할 일을 적으면 이 방에 불이 켜져요';

  @override
  String get billBadge => '청구서';

  @override
  String get addTaskLabel => '할 일 추가';

  @override
  String get endDayLabel => '하루 마치기';

  @override
  String get lampOn => '켜짐';

  @override
  String get lampOff => '꺼짐';

  @override
  String weekNumber(int n) {
    return '$n주차';
  }

  @override
  String get weekProgressLabel => '이번 주 진행';

  @override
  String get weekAllDone => '이번 주 할 일을 다 했어요';

  @override
  String get weekEmpty => '이번 주엔 아직 계획이 없어요';

  @override
  String addToDay(String day) {
    return '$day에 추가';
  }

  @override
  String openDay(String day) {
    return '$day 열기';
  }

  @override
  String get lastWeek => '지난주';

  @override
  String get nextWeek => '다음주';

  @override
  String weekRange(String from, String to) {
    return '$from ~ $to';
  }

  @override
  String get thisWeek => '이번 주';

  @override
  String get thisWeekLabel => '이번 주';

  @override
  String get collapse => '접기';

  @override
  String get add => '추가';

  @override
  String get edit => '편집';

  @override
  String get delete => '삭제';

  @override
  String get deleteThisTask => '이 할 일만 삭제';

  @override
  String get deleteFutureRecurring => '이 할 일과 앞으로의 반복 모두 삭제';

  @override
  String get close => '닫기';

  @override
  String get save => '저장';

  @override
  String get share => '공유';

  @override
  String get cancel => '취소';

  @override
  String get taskHint => '할 일';

  @override
  String get addMemo => '메모 추가';

  @override
  String get lumiSleepingNotice => 'Lumi가 자고 있어요. 내일 방에 놓아둘게요';

  @override
  String get lumiPokeLabel => '루미';

  @override
  String get lumiAway => 'Lumi는 오늘의 방에 있어요';

  @override
  String get toastTaskDeleted => '방에서 치웠어요';

  @override
  String get undo => '되돌리기';

  @override
  String get toastTaskAdded => '새 불이 켜졌어요';

  @override
  String get dateToday => '오늘';

  @override
  String get dateTomorrow => '내일';

  @override
  String get dateDayAfter => '모레';

  @override
  String get chooseDate => '날짜 선택';

  @override
  String get repeatSection => '반복';

  @override
  String get repeatNone => '반복 없음';

  @override
  String get repeatDaily => '매일';

  @override
  String get repeatWeekdays => '주중';

  @override
  String get repeatWeekly => '매주';

  @override
  String get repeatMonthly => '매월';

  @override
  String repeatEveryWeekday(String weekday) {
    return '매주 $weekday';
  }

  @override
  String repeatEveryMonthDay(String day) {
    return '매월 $day일';
  }

  @override
  String get weekdaysShort => '월,화,수,목,금,토,일';

  @override
  String get weekdaysLong => '월요일,화요일,수요일,목요일,금요일,토요일,일요일';

  @override
  String get monthsShort => '1,2,3,4,5,6,7,8,9,10,11,12';

  @override
  String monthDay(String monthName, int month, int day) {
    return '$month월 $day일';
  }

  @override
  String get billTitle => 'Unwind 전기요금 청구서';

  @override
  String billTotalCaption(String kwh, String fee) {
    return '총 $kwh kWh · 기본료 $fee 포함';
  }

  @override
  String wonAmount(String amount) {
    return '$amount원';
  }

  @override
  String get sleepDeep => 'Lumi는 푹 잤어요';

  @override
  String get sleepWell => 'Lumi는 잘 잤어요';

  @override
  String get sleepTossed => 'Lumi는 조금 뒤척였어요';

  @override
  String get sleepBarely => 'Lumi는 겨우 눈을 붙였어요';

  @override
  String get sleepNone => 'Lumi는 밤새 깨어 있었어요';

  @override
  String nightsOut(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '이번 주엔 $count일 밤 불을 껐어요',
    );
    return '$_temp0';
  }

  @override
  String get allNightsLit => '이번 주의 밤은 모두 불이 켜져 있었어요';

  @override
  String diffLess(String amount) {
    return '지난주보다 $amount 적어요';
  }

  @override
  String diffMore(String amount) {
    return '지난주보다 $amount 많아요';
  }

  @override
  String get diffSame => '지난주와 같은 요금이에요';

  @override
  String get notifNightReminder => 'Lumi가 잘 시간인데 아직 불이 켜져 있어요';

  @override
  String get notifBillArrived => '지난주 청구서가 도착했어요';

  @override
  String get settingsTitle => '설정';

  @override
  String get sectionNotifications => '알림';

  @override
  String get nightReminder => '취침 알림';

  @override
  String get nightReminderCaption => '취침시간에 불이 남아 있으면 알려드려요';

  @override
  String get billNotification => '청구서 도착';

  @override
  String get billNotificationCaption => '매주 월요일 아침에 지난주 청구서를 알려드려요';

  @override
  String get sectionFeel => '감각';

  @override
  String get sound => '사운드';

  @override
  String get haptics => '햅틱';

  @override
  String get sectionDay => 'Lumi의 하루';

  @override
  String get wakeTime => '기상시간';

  @override
  String get wakeTimeCaption => 'Lumi가 일어나면 새 하루가 시작돼요';

  @override
  String get bedtime => '취침시간';

  @override
  String get bedtimeCaption => '이 시각까지는 불을 다 꺼 줘야 해요';

  @override
  String hourLabel(int hour) {
    return '$hour시';
  }

  @override
  String get sectionLanguage => '언어';

  @override
  String get language => '언어';

  @override
  String get sectionData => '데이터';

  @override
  String get eraseData => '데이터 초기화';

  @override
  String get eraseDataCaption => '모든 할 일과 기록을 지워요';

  @override
  String get eraseDataDialogBody => '모든 할 일과 기록이 지워져요. 되돌릴 수 없어요.';

  @override
  String get erase => '지우기';

  @override
  String get fullResetDev => '완전 초기화 (개발용)';

  @override
  String get fullResetDevCaption => '설정까지 전부 지우고 첫 실행 상태로 돌아가요';

  @override
  String get obNext => '다음';

  @override
  String get obWelcomeTitle => 'Lumi와 함께, 오늘을 잘 끝내요';

  @override
  String get obWelcomeBody =>
      '당신의 방에 사는 꼬마 유령 Lumi예요. 당신이 하루를 잘 끝내야 Lumi가 잠들 수 있어요.';

  @override
  String get obNightTitle => '밤이 되면 Lumi는 자야 해요';

  @override
  String get obNightBody => '그런데 방의 불이 아직 켜져 있어요. 눈이 부셔서 도무지 잠들 수가 없어요.';

  @override
  String get obLightsTitle => '할 일 하나가 등 하나예요';

  @override
  String get obLightsBody => '끝낸 일의 스위치를 내리면 불이 꺼져요. 전부 꺼 보세요.';

  @override
  String get obLightsDone => '모든 불이 꺼졌어요 — 잘 자요, Lumi';

  @override
  String get obDummy1 => '물 2L 마시기';

  @override
  String get obDummy2 => '운동하기';

  @override
  String get obDummy3 => '30분 책 읽기';

  @override
  String get obBillTitle => '매주 월요일, 청구서가 도착해요';

  @override
  String get obBillBody => '밤에 남긴 불빛은 밤새 전기를 써요. 청구서를 눌러 영수증을 미리 봐요.';

  @override
  String get obQuestionsTitle => '이제 몇 가지만 물어볼게요';

  @override
  String get obQuestionsBody => 'Lumi가 당신의 하루에 맞춰 지내려고요.';

  @override
  String get obHabitsTitle => '매일 꼭 하는 일이 있나요?';

  @override
  String get obHabitsBody => '한 번 적어 두면, 매일 아침 등이 미리 켜져 있을 거예요.';

  @override
  String get obHabitsHint => '예: 5분 스트레칭';

  @override
  String get obHabitsNone => '아직 없어요';

  @override
  String get obHabitsDefault => '물 2L 이상 마시기';

  @override
  String get obSleepQTitle => '보통 몇 시에 잠들어요?';

  @override
  String get obSleepQBody => '잠꾸러기 Lumi는 당신보다 세 시간 먼저 잠들어요.';

  @override
  String obSleepQResult(String time) {
    return 'Lumi의 취침시간은 $time이 돼요';
  }

  @override
  String get obWakeQTitle => '보통 몇 시에 일어나요?';

  @override
  String get obWakeQBody => 'Lumi는 한 시간 먼저 일어나 하루를 열어 둬요.';

  @override
  String obWakeQResult(String time) {
    return 'Lumi는 $time에 일어날 거예요';
  }

  @override
  String get obScheduleTitle => 'Lumi의 하루가 정해졌어요';

  @override
  String obScheduleBody(String bed, String wake) {
    return '$bed에 잠들고 $wake에 일어나요 — 언제나 당신보다 조금 먼저요.';
  }

  @override
  String get obNameTitle => 'Lumi가 뭐라고 부르면 좋을까요?';

  @override
  String get obNameHint => '이름';

  @override
  String get obSkip => '건너뛰기';

  @override
  String get obBegin => '시작하기';

  @override
  String obGreeting(String name) {
    return '만나서 반가워요, $name!';
  }

  @override
  String get obGreetingNoName => '만나서 반가워요!';

  @override
  String get m0Reset => '처음부터 다시 체험하기 (M0 테스트용)';

  @override
  String get autoDeferTitle => '자동으로 미루기';

  @override
  String get autoDeferSubtitle => '오늘 안 하면 내일의 할 일로 등록돼요';

  @override
  String get taskTime => '시간';

  @override
  String get taskTimeNone => '시간 없음';

  @override
  String get todoReminderBody => '10분 뒤 이 불을 끌 시간이에요';
}
