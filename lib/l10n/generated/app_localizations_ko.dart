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
  String get memoHint => '메모';

  @override
  String get addMemo => '메모 추가';

  @override
  String get lumiSleepingNotice => 'Lumi가 자고 있어요. 내일 방에 놓아둘게요';

  @override
  String get dateToday => '오늘';

  @override
  String get dateTomorrow => '내일';

  @override
  String get dateDayAfter => '모레';

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
  String get weekdaysShort => '월,화,수,목,금,토,일';

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
  String get notifNightReminder => 'Lumi가 아직 못 자고 있어요';

  @override
  String get notifBillArrived => '지난주 청구서가 도착했어요';

  @override
  String get settingsTitle => '설정';

  @override
  String get sectionNotifications => '알림';

  @override
  String get nightReminder => '밤 리마인더';

  @override
  String get nightReminderCaption => 'Lumi가 아직 못 자고 있을 때 알려드려요';

  @override
  String get reminderTime => '리마인더 시각';

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
  String get sectionDay => '하루';

  @override
  String get dayStart => '하루 시작 시각';

  @override
  String get dayStartCaption => '이 시각 전까지는 어제의 방이에요';

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
  String get onboardTitle => 'Lumi는 자고 싶어요';

  @override
  String get onboardBody =>
      '할 일 하나가 등 하나예요.\n하나씩 끝내면 방이 조금씩 어두워져요.\n마지막 불이 꺼지면 Lumi가 잠들어요.';

  @override
  String get onboardGo => '불 끄러 가기';

  @override
  String get onboardTransition => '이제 진짜 오늘의 할 일을 적어볼까요';

  @override
  String get onboardStart => '적으러 가기';

  @override
  String get onboardSample1 => '오늘 온 메일에 답장하기';

  @override
  String get onboardSample2 => '빌린 책 반납하기';

  @override
  String get onboardSample3 => '저녁 산책 20분';

  @override
  String get m0Reset => '처음부터 다시 체험하기 (M0 테스트용)';
}
