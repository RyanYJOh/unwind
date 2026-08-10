# Unwind — 에이전트 컨텍스트 (정본)

> 이 문서는 Cursor·Claude Code 등 어떤 LLM 도구가 와도 이 앱의 맥락을 완전히
> 파악할 수 있게 하는 정본이다. 구조·정책이 바뀌면 **반드시 이 문서를 갱신**하고,
> PRD급 규칙 변경은 발주자 컨펌 후 `docs/prd-amendments.md`에 기록한다.

## 1. 컨셉 (절대 훼손 금지)

**하루를 끝내는 앱.** 할 일 하나 = 방의 등(전등 스위치) 하나. 체크할 때마다
방이 어두워지고, 마지막 불을 끄면(또는 전등 줄을 당기면) 유령 **Lumi**가
만족스럽게 잠든다. 생산성 앱이 아니라 "오늘을 잘 닫는" 릴랙스 앱이다.

- 모든 색·분위기는 조도 **t** 하나에서 파생된다 (0.0 = 정오처럼 밝음, 1.0 = 밤).
- 진행률·퍼센트·개수·체크마크 같은 생산성 어휘를 UI에 쓰지 않는다.
- 사용자를 다그치지 않는다 — 빈 방은 사과가 아니라 초대의 문구.
- 주간 청구서(전기요금 은유): 남긴 불빛이 얼마나 전기를 썼는지 영수증으로.

## 2. 스택 · 실행

Flutter + Riverpod 3 + Drift(SQLite). **로컬 온리, 서버 없음.**

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs  # Drift 코드젠 (*.g.dart)
flutter gen-l10n                                          # l10n (generated도 커밋됨)
flutter analyze && flutter test                           # 74개 통과가 기준선
flutter run                                               # 개발 실행
flutter build ipa                                         # TestFlight용 (버전은 pubspec)
```

- 버전: `pubspec.yaml`의 `version: X.Y.Z+N` — TestFlight 업로드마다 `+N` 증가.
- l10n: `lib/l10n/app_en.arb`(기본)·`app_ko.arb` 수정 → `flutter gen-l10n`.
  두 파일 모두에 키를 넣어야 한다. 문구는 은유를 따른다 (버튼은 동사).

## 3. 디렉토리 지도

```
lib/
  core/tokens/       색 램프(color_ramp)·타이포·간격·모션·디자인 변형 상수
                     → 값 하드코딩 금지. 모든 UI는 이 토큰만 사용
  core/theme/        UnwindTheme(InheritedWidget) + PrimaryText(텍스트 크로스페이드)
  core/haptics/, core/sound/, core/utils/dates.dart(dayKey 유틸)
  data/db/           Drift 테이블·DAO (todos, days, recurrences, weekly_bills, settings)
  data/repositories/ todo_repository(setDone/wake/lightsOut...), bill_repository
  domain/services/   brightness_engine, bill_calculator(순수 계산, 테스트 필수),
                     recurrence_expander, day_rollover_service, notification_service
  domain/models/     lumi_state.dart — LumiState/LumiMode/LumiDayActivity (렌더러 계약)
  features/
    today/           providers.dart(앱 상태의 중심) + today_screen.dart(홈)
    week/            weekly_strip.dart(하단 최근 30일 스트립), week_screen.dart(주간 뷰)
    compose/         입력 시트 + date_bar
    bill/            주간 청구서 (영수증 렌더 + 이미지 공유)
    settings/        설정 + ghost_demo_screen(dev)
    onboarding/      3단계 온보딩 (M0 프로토타입 재사용)
  widgets/           lamp_row(스위치 행), pull_cord(전등 줄), corner_glow(핵심 조명),
                     night_sky, top_toast, lumi/(캐릭터)
```

## 4. 상태 아키텍처 (features/today/providers.dart)

### 날짜 축 — 두 계열을 절대 섞지 말 것
- `todayKeyProvider` — **실제 오늘** (dayStartHour 기본 06시 기준 롤오버).
  야간 리마인더·청구서 생성·반복 전개 등 **서비스**는 전부 이쪽
  (`todayTodosProvider`/`todayDayProvider`).
- `selectedDateProvider`(null=오늘 따라감) → `viewedDayKeyProvider` — **화면이
  보여주는 날짜**. 하단 스트립에서 과거 날짜를 고르면 홈 전체(리스트·조도·
  Lumi·타이틀)가 그 날짜의 방으로 바뀐다. 화면용 데이터는
  `viewedTodosProvider`/`viewedDayProvider`.

### 조도 t — 단일 진실
`brightnessProvider`: 소등(lightsOutAt) → 1.0 / 과거 날짜 → 그날의 `finalT` /
빈 방 → emptyRoomT / 그 외 → `peakProgress`(단조 증가 — 체크 해제해도 방은
다시 밝아지지 않는 게 규칙, §5.2). 화면은 이 목표값을 애니메이션으로 따라간다
(도미노 중엔 시퀀스가 직접 몬다).

### 주요 파생 프로바이더
- `isAsleepProvider` — 열람 날짜의 lightsOutAt 존재 여부 (방 취침 상태)
- `pullCordEnabledProvider` — 오늘 열람 + 항목 있음 + 아직 안 당김
- `weekWindowsProvider` — 하단 스트립 데이터 (오늘 포함 최근 `kStripDays`=30일)
- `lumiModeProvider` — Lumi 생활 모드 (아래 §6)
- `clockProvider` — 1분 시계 (시간대 전환 감지)

## 5. 조도·룸 디자인 시스템

- `core/tokens/color_ramp.dart` — PRD §8.1 정거장(S0 정오~S5 밤) 표. **임의 변경
  금지** (변경했다면 반드시 prd-amendments에 근거 기록). `lerpRamp(t)` →
  `UnwindColors`. 텍스트는 t=0.67에서 어두운↔밝은 쪽 180ms 크로스페이드
  (`PrimaryText` 사용 — 절대 보간하지 않음).
- `core/tokens/design_variant.dart`의 `kRoomDesign` = **darkGlow** (현행):
  베이스는 항상 밤 색(`lerpRamp(1.0)`)이고, 남은 빛은 우측 상단 **CornerGlow**
  (4겹 RadialGradient)가 표현한다. `light = 1 - t`. 이전 컨셉(ceilingLight,
  fluorescent)은 롤백용으로 코드에 보존.
- **§11 성능: 블러 금지.** 발광·그림자·볼터치까지 전부 gradient로 그린다.
  (BoxShadow blur는 스위치 인디케이터 같은 소형 요소만 예외적으로 사용 중.)
- **§12 접근성**: 터치 타깃 44pt(UnwindTouch.minTarget), 대비 4.5:1,
  Reduce Motion 시 모든 장식 애니메이션 정지(위상 기반이라 자동 정지됨),
  제스처(당기기)에는 반드시 Semantics 대체 액션.
- 간격·반경·모션 상수는 `UnwindSpacing/UnwindRadius/UnwindMotion` — 하드코딩 금지.

## 6. Lumi (캐릭터) — widgets/lumi/

렌더 계층: `LumiView`(앱 계약: LumiState) → `GhostView`(Rive 브리프 계약)
→ `.riv` 있으면 Rive / 없으면 **`GhostPainterView`가 실제 렌더러** (현재 .riv 없음).

### 생활 모드 (lumiModeProvider가 결정)
1. **asleep** — 소등했거나 / 전부 체크(시간 무관) / 밤(19시~)의 빈 방 / 과거
   날짜의 완료된 밤. 감은 ∪눈 + 만족 미소 + zzz + 손 처짐.
2. **day** (dayStartHour~19시) — 행복한 펫. 2시간 슬롯 일과
   (enum 순서 = 슬롯): stretch(06) → coffee(08) → read(10) → walk(12) →
   hum(14) → snack(16) → rest(18). 소품(잔·책·안경·쿠키·음표)은 본체와 분리된
   레이어 — 외형을 바꿔도 소품 코드는 유지된다. 커피·간식은 오른쪽 기본 팔을
   숨기고 손만 소품에 겹쳐 쥔 모습으로 표현하며, 독서는 양쪽 기본 팔을 숨기고
   책을 받치는 손 두 개 + 안경만 그린다. 소품 상태에서는 내부 팔을 그리지 않는다.
3. **nightAwake** (19시~, 미완 항목 존재) — 못 자는 밤. `dazzle = 1 - t`:
   빛이 많이 남았으면(≥0.45→squint) **찡그린 ∩눈**, 어두우면 **꾸벅꾸벅**
   (고개 사이클 + 눈꺼풀 동조). 눈부심·꾸벅 모두 위·아래 곡면 눈꺼풀과
   가장자리 선으로 표현하며, 강한 눈부심은 압착 눈꺼풀·안쪽이 들린 눈썹·
   눈꼬리 주름으로 괴로운 표정을 만든다. 입은 처진 곡선(웃음 금지),
   하품은 동그란 O.

### 디자인 규칙 (2026-08-09 현행)
- 실루엣: **반원 돔**(arcToPoint) + 수직 접선으로 부드럽게 이어지는 통통한
  옆선(어깨 곡률 급변 없음) + 봉우리가 둥근 물결 스캘럽 4개. 팔은 짧고
  둥근 **작은 플리퍼**.
- 셰이딩: 흰→라벤더 수직 그라데이션, 좌우 하단의 라벤더·블루 음영,
  중앙 광택과 정수리 하이라이트, 옅은 분홍 볼터치.
- 눈은 첨부 레퍼런스보다 크게 강조하며, 흰자·네이비 홍채·동공·이중
  캐치라이트·윗눈꺼풀 선이 있는 세미리얼 구조다. 작은 홈 크기에서도 눈의
  입체감과 졸림에 따른 눈꺼풀 변화가 선명하게 읽혀야 한다.
- 아웃라인 잉크 `#1E1A2E`, 몸통 4.2u.
- 이벤트: checkOff(통통) / allDone(잠들기) / wakeUpHappy(기상 기지개) —
  `eventTick` 증가로 같은 이벤트 연속 발사.
- 금지: 화난 표정. (찡그림은 2026-08-09부터 밤 눈부심에 한해 허용.)
- `mode == null`이면 레거시(brightness→졸림) — 온보딩이 이 모드를 쓴다.

## 7. 홈 화면 구성 (today_screen.dart, 위→아래)

1. 설정 아이콘 + 날짜 타이틀("Today" / 과거면 "Aug 7") + 미확인 청구서 배지
2. Lumi (고정 높이 136pt, size 118)
3. 체크리스트 — `LampRow`: 좌 텍스트(완료 시 삭선), 우 벽 로커 스위치
   (ON 인디케이터는 3겹 발광). 스위치=토글, 행 탭=편집 시트, 롱프레스=삭제만,
   왼쪽 스와이프=해당 항목 삭제. 반복 항목의 롱프레스 삭제는 단일/현재 이후
   전체 중 선택한다. 반복 단건 삭제는 `deferred` tombstone을 남겨 다음 전개 때
   같은 회차가 되살아나지 않게 한다. 취침 중 스위치 ON = **깨우기(undo)**.
4. 하단 행 — 좌: **최근 30일 스트립**(가로 스크롤, reverse라 오늘이 항상 오른쪽
   끝), 우: **Bill 버튼**(`assets/images/bill.png`, 래퍼 없음). 스트립 셀 =
   정방형 창(그날의 조도 색) + 그날 밤 Lumi의 눈(밝을수록 졸린 실눈 / 소등이면
   감은 눈, **기록 있는 완주 날엔 스마일**). 라벨 "8.2"(월.일). 탭 = 날짜 열람.
5. FAB(주황 +) — 과거 열람 중엔 그 날짜로 추가.
6. 전등 줄(PullCord, 우측 상단에서 늘어짐) — 당기면 70ms 도미노 소등 시퀀스
   (§9.3: 절대 동시에 끄지 않는다, 마지막 등 후 500ms 정적). 히트 영역은
   painter.hitTest로 제한(리스트 가림 방지).
7. 항목 추가 시 상단 푸시형 토스트(top_toast.dart).
8. 주간 뷰(WeekScreen)는 오버레이로 남아 있으나 **현재 진입점 없음** (스트립이
   날짜 선택으로 바뀌면서). 붙이거나 제거할지 미정.

## 8. 도메인 규칙 요약

- **롤오버**: dayStartHour(기본 06시) 전까지는 어제의 방. 과거 방의 finalT를
  먼저 봉인한 뒤 `pending && autoDefer` 원본 행을 오늘로 이동하고, 반복 전개와
  지난주 청구서 생성을 수행한다. 자동 미루기는 반복과 상호 배제한다.
- **청구서** (§6.5): 등 하나 = 0.06kWh/h, 152원/kWh + 기본료 730원, 10원 반올림.
  bill_calculator는 순수 로직 + 단위 테스트 필수. 월요일 아침 알림.
- **알림** (§10): 밤 리마인더(기본 22시, 미완+미소등일 때만), 청구서 도착,
  시간 지정 Todo의 10분 전 알림. Todo 알림은 실제 기기 타임존을 사용하고,
  완료·삭제·시간 제거·오늘 소등 시 취소한다. 권한 요청은 온보딩 종료 후.
- **반복**: 규칙 저장 → recurrence_expander가 롤오버마다 인스턴스 생성.
  주간/월간 라벨은 선택 날짜 기준 `Every Monday`/`Every 3rd`처럼 표시하며,
  규칙의 지정 시간은 모든 생성 회차에 전파한다.
- 입력 시트: 키보드 위 바는 좌 달력 아이콘 / 중앙 날짜 이동 / 우 원형 화살표
  저장 CTA로 추가·편집이 동일하다. 저장 후 키보드를 닫고, 편집 저장은 시트도
  닫는다. 편집 중 날짜 변경 시 해당 Todo를 새 날짜의 마지막 순서로 이동한다.
  자동 미루기 체크와 선택 시간 필드가 있으며, 목록은 시간 있음(이른 순) →
  시간 없음(sortIndex 순)으로 정렬한다. 취침 후 기본 날짜는 내일.

## 9. 개발용 기능 (배포 전 제거 대상)

- 설정 > **Ghost demo (dev)** — 모든 모드/활동/이벤트 프리뷰 칩. 캐릭터 작업 시
  여기서 검증하는 것이 가장 빠르다.
- 설정 > **Full reset (dev)**, 홈의 **Bill 버튼은 현재 더미 데이터**
  (`_openDummyBill` — 지난주 가짜 청구서).
- `features/today/m0_prototype_screen.dart` — 온보딩 2단계가 재사용 (보존).

## 10. 검증 루틴

1. `flutter analyze` — 0 이슈 유지.
2. `flutter test` — 74개 전부 통과가 기준선. UI 변경 시 위젯 테스트가 히트
   영역 겹침 같은 실제 버그를 잡아 온 전적이 있다.
3. 시뮬레이터 확인 — 캐릭터는 Ghost demo에서, 상태 흐름은 홈에서.
   (Claude Code는 `flutter run` 백그라운드 + `kill -USR1 <pid>`로 hot reload.)

## 11. 이력·문서

- `docs/prd-amendments.md` — PRD 개정 기록 (컨펌된 것만).
- `README.md` — 셋업 안내.
- PRD 원문(`unwind-prd-v1.md`)·Rive 브리프는 **저장소에 없다** — 코드 주석의
  §번호가 그 조항을 가리키며, 위 §5·§8의 요약이 현행 규칙이다.
- 큰 개편 이력: 2026-08-07 darkGlow 컨셉/벽 스위치/깨우기, 2026-08-08 카와이
  캐릭터 개편·생활 모드(일과/밤)·하단 스트립, 2026-08-09 날짜 열람(viewed)·
  30일 스트립·반원 실루엣·손에 쥔 소품·밤 표정(찡그림·하품·처진 입).
