// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appName => '토드';

  @override
  String get today => '오늘';

  @override
  String get emptyRoomTitle => '할 일이 없어';

  @override
  String get emptyRoomSubtitle => '잠깐.. 그럼 불을 어떻게 끄지..?';

  @override
  String get billBadge => '청구서';

  @override
  String get addTaskLabel => '할 일 추가';

  @override
  String get endDayLabel => '하루 마치기';

  @override
  String get pullCordCoach => '손잡이를 아래로 쭉 당겨 봐.';

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
  String get weekAllDone => '이번 주 할 일을 다 했어';

  @override
  String get weekEmpty => '이번 주엔 아직 계획이 없어';

  @override
  String get weekIncompleteOnly => '미완료 할 일';

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
  String get toddSleepingNotice => '토드가 자고 있어. 내일로 넣어둘게';

  @override
  String get toddPokeLabel => '토드';

  @override
  String get toddAway => '토드는 오늘의 방에 있어';

  @override
  String get toastTaskDeleted => '삭제되었어';

  @override
  String get undo => '되돌리기';

  @override
  String get toastTaskAdded => '새 불이 켜졌어';

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
  String get billTitle => '전기요금 청구서';

  @override
  String billTasksClosed(int done, int total) {
    return '$done / $total';
  }

  @override
  String get billTasksCaption => '지난주에 끝낸 일';

  @override
  String billTotalCaption(String kwh) {
    return '밤새 켜 둔 불 $kwh kWh';
  }

  @override
  String get billMondayOnly => '청구서는 매주 월요일에만 열 수 있어';

  @override
  String get billMondayOnlyBody => '그때까지 이번 주 할 일들을 잘 해나가 보자!';

  @override
  String wonAmount(String amount) {
    return '$amount원';
  }

  @override
  String get sleepDeep => '토드가 완벽하게 잤어요';

  @override
  String get sleepWell => '토드가 꽤 잘 잤어요';

  @override
  String get sleepTossed => '토드가 조금 뒤척였어요';

  @override
  String get sleepBarely => '토드가 겨우 눈을 붙였어요';

  @override
  String get sleepNone => '토드가 밤새 깨어 있었어요';

  @override
  String nightsOut(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '이번 주엔 $count일 밤 불을 껐어',
    );
    return '$_temp0';
  }

  @override
  String get allNightsLit => '이번 주의 밤은 모두 불이 켜져 있었어';

  @override
  String diffLess(String amount) {
    return '지난주보다 $amount 적어';
  }

  @override
  String diffMore(String amount) {
    return '지난주보다 $amount 많아';
  }

  @override
  String get diffSame => '지난주와 같은 요금이야';

  @override
  String get notifNightReminder => '나 이제 자고 싶은데.. 너무 밝다..';

  @override
  String get notifBillArrived => '지난주 청구서가 도착했어!';

  @override
  String get notifMorningGreeting => '좋은 아침! 난 방금 일어났어';

  @override
  String notifMorningGreetingNamed(String name) {
    return '좋은 아침이야, $name! 난 방금 일어났어';
  }

  @override
  String notifMorningGreetingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '좋은 아침! 오늘 할 일 $count개, 같이 해치우자 💪',
    );
    return '$_temp0';
  }

  @override
  String get settingsTitle => '설정';

  @override
  String get sectionNotifications => '알림';

  @override
  String get pushSettings => '푸시';

  @override
  String get pushSettingsCaption => '아침 인사, 하루 마무리, 시간 알림, 청구서';

  @override
  String get pushSettingsTitle => '푸시';

  @override
  String get morningGreeting => '아침 인사';

  @override
  String get morningGreetingCaption => '토드가 일어난 지 한 시간 뒤에';

  @override
  String get nightReminder => '하루 마무리';

  @override
  String get nightReminderCaption => '취침 30분 전에 불이 남아 있으면 알려줄게';

  @override
  String get todoReminder => '시간 알림';

  @override
  String get todoReminderCaption => '시간이 있는 할 일 10분 전에';

  @override
  String get billNotification => '청구서 도착';

  @override
  String get billNotificationCaption => '매주 월요일 아침에 지난주 청구서를 알려줄게';

  @override
  String get sectionFeel => '감각';

  @override
  String get sectionLight => '조명 색';

  @override
  String calendarHeader(String month, String year) {
    return '$year년 $month월';
  }

  @override
  String get plusTitle => 'TODD PLUS';

  @override
  String get plusHeroTitle => '우리 조금 더\n가까워져 볼까?';

  @override
  String get plusHeroThanks => '야호!\n우린 이제 한 팀이야';

  @override
  String get plusFeatureColors => '조명 색 7가지 변경';

  @override
  String get plusFeatureColorsCaption => '하나씩 직접 눌러봐! 👇';

  @override
  String get plusFeatureRecurrence => '반복 할 일 무제한';

  @override
  String get plusFeatureRecurrenceCaption => '일일이 신경 쓸 필요 없어!';

  @override
  String get plusFeatureMore => '…혜택이 계속해서 추가될 거래';

  @override
  String get plusMonthly => '월간';

  @override
  String get plusMonthlyPrice => '₩4,900';

  @override
  String get plusMonthlyCaption => '매달 결제';

  @override
  String get plusYearly => '연간';

  @override
  String get plusYearlyPrice => '₩29,000';

  @override
  String get plusYearlyCaption => '한 달에 약 ₩2,400';

  @override
  String get plusLifetime => '평생';

  @override
  String get plusLifetimePrice => '₩79,000';

  @override
  String get plusLifetimeCaption => '한 번이면 평생 함께';

  @override
  String get plusBest => 'BEST';

  @override
  String get plusCta => '토드와 함께하기';

  @override
  String get plusCancelNote => '언제든 해지할 수 있어!';

  @override
  String get plusSettingsCaption => '토드와 더 가까워지기';

  @override
  String get plusSettingsActive => '함께하는 중 💛';

  @override
  String get lightAmber => '앰버';

  @override
  String get lightSunset => '노을';

  @override
  String get lightRose => '로즈';

  @override
  String get lightLavender => '라벤더';

  @override
  String get lightSky => '하늘';

  @override
  String get lightMint => '민트';

  @override
  String get lightMoon => '달빛';

  @override
  String get haptics => '햅틱';

  @override
  String get sectionDay => '나의 하루';

  @override
  String get wakeTime => '기상시간';

  @override
  String wakeTimeCaption(String time) {
    return '토드는 $time에 일어나요';
  }

  @override
  String get bedtime => '취침시간';

  @override
  String bedtimeCaption(String time) {
    return '토드는 $time에 자야 해요';
  }

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
  String get eraseDataCaption => '모든 할 일과 기록을 지워';

  @override
  String get eraseDataDialogBody => '모든 할 일과 기록이 지워져. 되돌릴 수 없어.';

  @override
  String get erase => '지우기';

  @override
  String get fullResetDev => '완전 초기화 (개발용)';

  @override
  String get fullResetDevCaption => '설정까지 전부 지우고 첫 실행 상태로 돌아가';

  @override
  String get obNext => '다음';

  @override
  String get obHelloSleepy => '안녕, 난 토..ㄷ..';

  @override
  String get obHelloAwake => '앗 안녕! 난 토드야';

  @override
  String get obHelloAwakeBody => '미안, 내가 잠이 좀 많은 편이거든...';

  @override
  String get obWakeToastTitle => '토드가 잠들어 버렸어요!';

  @override
  String get obWakeToastBody => '톡톡 두드려서 깨워 주세요';

  @override
  String obWakeMoreToast(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '거의 깼어요 — $count번만 더 톡톡!',
    );
    return '$_temp0';
  }

  @override
  String get obWakeAction => '토드 깨우기';

  @override
  String get obNightTitle => '밤이 되면 자야 하는데..';

  @override
  String get obNightBody => '빛이 너무 밝아서 잠들 수가 없어.\n할 일을 체크해서 불을 꺼줄래?';

  @override
  String get obLightsDone => '완벽해!';

  @override
  String get obLightsDoneBody => '오늘 밤은 드디어 푹 잘 수 있겠다.\n고마워!';

  @override
  String get obDummy1 => '물 2L 마시기';

  @override
  String get obDummy2 => '헬스장 가기';

  @override
  String get obDummy3 => '30분 책 읽기';

  @override
  String get obBillTitle => '매주 월요일,\n청구서가 도착해.';

  @override
  String get obBillBody => '지난주에 불을 얼마나 켜뒀는지 보자.';

  @override
  String get obBillOnMe => '걱정 마 — 내가 낼게!';

  @override
  String get obQuestionsTitle => '이제 물어볼 게\n몇 가지 있어!';

  @override
  String get obQuestionsBody => '우리 서로 하루를 맞춰보자.';

  @override
  String get obHabitsTitle => '매일 하는 루틴이 있어?';

  @override
  String get obHabitsBody => '아니면 앞으로 하고 싶은 거라도!';

  @override
  String get obHabitsHint => '예: 5분 스트레칭';

  @override
  String get obHabitsNone => '아직 없어';

  @override
  String get obHabitsDefault => '물 2L 이상 마시기';

  @override
  String get obReadyTitle => '하루를 생산적으로\n관리할 준비 됐어?';

  @override
  String get obReadyNo => '🥱 아니, 별로';

  @override
  String get obReadySomewhat => '🙂 어느 정도';

  @override
  String get obReadyYes => '🤩 응, 기대돼!';

  @override
  String get obSleepQTitle => '보통 몇 시에 자?';

  @override
  String get obSleepQBody => '참고로, 난 좀 일찍 잠드는 편이야.';

  @override
  String obSleepQResult(String time) {
    return '나중에 바꿀 수 있어';
  }

  @override
  String get obWakeQTitle => '보통 몇 시에 일어나?';

  @override
  String get obWakeQBody => '난 아침형 유령이야.';

  @override
  String obWakeQResult(String time) {
    return '나중에 바꿀 수 있어';
  }

  @override
  String get obScheduleTitle => '내 하루는 이런 모습이야!';

  @override
  String obScheduleBody(String bed, String wake) {
    return '$bed에 잠들고 $wake에 일어나.';
  }

  @override
  String get obNameTitle => '마지막! 이름이 뭐야?';

  @override
  String get obNameHint => '이름';

  @override
  String get obBegin => '시작하기';

  @override
  String obGreeting(String name) {
    return '만나서 반가워, $name!';
  }

  @override
  String get obGreetingNoName => '만나서 반가워!';

  @override
  String get obNameToddCoincidence => '(엄청난 우연의 일치군..)';

  @override
  String get obWidgetTitle => '참, 하나만 더..';

  @override
  String get obWidgetBody => '위젯을 설치해두면\n할 일을 잊지 않을 수 있어!';

  @override
  String get obWidgetStep1 => '홈 화면으로 나가서';

  @override
  String get obWidgetStep2 => '빈 곳을 길게 누른 뒤,';

  @override
  String get obWidgetStep3 => '\'위젯 추가\'에서 토드를 찾으면 끝!';

  @override
  String get obWidgetCta => '좋아!';

  @override
  String get obWidgetPillLeft => '남음';

  @override
  String get m0Reset => '처음부터 다시 체험하기 (M0 테스트용)';

  @override
  String get autoDeferTitle => '자동으로 미루기';

  @override
  String get autoDeferSubtitle => '오늘 안 하면 내일의 할 일로 등록돼';

  @override
  String get taskTime => '시간';

  @override
  String get taskTimeNone => '시간 없음';

  @override
  String get notifTimedTitle => '10분 전 알림!';

  @override
  String notifTimedBody(String title) {
    return '곧 \"$title\" 할 시간이야';
  }

  @override
  String notifNightReminderTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '할 일이 $count개 남았어!',
    );
    return '$_temp0';
  }
}
