# Unwind — 에이전트 컨텍스트 (정본)

> 이 문서는 Cursor·Claude Code 등 어떤 LLM 도구가 와도 이 앱의 맥락을 완전히
> 파악할 수 있게 하는 정본이다. 구조·정책이 바뀌면 **반드시 이 문서를 갱신**하고,
> PRD급 규칙 변경은 발주자 컨펌 후 `docs/prd-amendments.md`에 기록한다.

## 1. 컨셉 (절대 훼손 금지)

**하루를 끝내는 앱.** 할 일 하나 = 방의 등(전등 스위치) 하나. 체크할 때마다
방이 어두워지고, 마지막 불을 끄면(또는 전등 줄을 당기면) 유령 **Lumi**가
만족스럽게 잠든다. 생산성 앱이 아니라 "오늘을 잘 닫는" 릴랙스 앱이다.

- 방의 **남은 빛**은 조도 **t** 하나가 정한다 (0.0 = 빛이 가득, 1.0 = 소등).
  단, v2부터 t는 색이 아니라 **빛의 양**만 몬다 — 팔레트는 고정 다크다 (§5.1).
- 진행률·퍼센트·개수·체크마크 같은 생산성 어휘를 UI에 쓰지 않는다.
- 사용자를 다그치지 않는다 — 빈 방은 사과가 아니라 초대의 문구.
- 주간 청구서(전기요금 은유): 남긴 불빛이 얼마나 전기를 썼는지 영수증으로.

## 2. 스택 · 실행

Flutter + Riverpod 3 + Drift(SQLite). **로컬 온리, 서버 없음.**

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs  # Drift 코드젠 (*.g.dart)
flutter gen-l10n                                          # l10n (generated도 커밋됨)
flutter analyze && flutter test                           # 91개 통과가 기준선
flutter run                                               # 개발 실행
flutter build ipa                                         # TestFlight용 (버전은 pubspec)
```

- 버전: `pubspec.yaml`의 `version: X.Y.Z+N` — TestFlight 업로드마다 `+N` 증가.
- l10n: `lib/l10n/app_en.arb`(기본)·`app_ko.arb` 수정 → `flutter gen-l10n`.
  두 파일 모두에 키를 넣어야 한다. 문구는 은유를 따른다 (버튼은 동사).

## 3. 디렉토리 지도

```
lib/
  core/tokens/       palette(고정 다크 팔레트)·타이포·간격/깊이·모션 상수
                     → 값 하드코딩 금지. 모든 UI는 이 토큰만 사용
  core/haptics/      UnwindHaptics(햅틱 어휘) + UnwindHapticsScope(트리 주입)
  core/sound/, core/utils/dates.dart(dayKey 유틸)
  ui/                **재사용 컴포넌트 라이브러리 (ui.dart 하나만 import)**
                     화면에 일회용 위젯을 두지 말고 여기에 만들어 쓴다 (§5.5)
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
    dev/             design_gallery_screen(dev) — 컴포넌트 전수 검증
    onboarding/      3단계 온보딩 (M0 프로토타입 재사용)
  widgets/           pull_cord(전등 줄), corner_glow(핵심 조명), night_sky,
                     lumi/(캐릭터)
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

## 5. 디자인 시스템 v2 (2026-08-12 전면 개편)

듀오링고의 문법을 따르되 컬러는 절제한다. 근거·이전 규칙과의 차이는
`docs/prd-amendments.md` 2026-08-12 항목에 전부 기록돼 있다.

### 5.1 색 — `core/tokens/palette.dart`
- **PRD §8.1 조도 램프는 폐기됐다.** 색은 t에서 파생되지 않는다.
  앱은 **항상 다크**이고, `UnwindColors`는 고정 상수 묶음이다
  (InheritedWidget 없음 — 어디서든 `UnwindColors.surface`처럼 직접 쓴다).
- 조도 `t`는 이제 색이 아니라 **빛의 양**만 몬다: CornerGlow 세기,
  주간 스트립 창의 밝기(`UnwindColors.window(light)`). "남은 할 일 = 남은 빛"
  은유는 그대로다.
- **CornerGlow는 눈부실 만큼 밝아야 한다** (재조정 2026-08-12): 할 일이 가득한
  방은 Lumi가 잠들 수 없을 정도여야 하고, 그래야 하나씩 끌 때 어두워지는 게
  읽힌다. 빛 응답은 **선형**이다 — easeOut을 쓰면 위쪽 구간이 평평해져 등을
  하나 꺼도 차이가 보이지 않는다. 좌하단은 언제나 어둠에 남는다.
- 이렇게 밝아지면 상단은 배경 대비가 흔들린다. 그 위에 얹는 것은 **불투명
  채움**을 가져야 한다 (타일·토스트·청구서 배지 모두 그렇게 되어 있다).
- 중립은 슬레이트-네이비 한 계열: `ink`(배경) → `surface` → `surfaceAlt` →
  `surfaceHigh`, 테두리 `border`/`borderStrong`, 압출면 `solid`.
- **포인트 컬러는 둘뿐. 새 색 추가 금지.**
  - `accent` 앰버 `#FFB224` — 빛·켜진 등·CTA·선택. (+ `accentDeep` 압출면,
    `accentSoft` 채움, `accentEdge` 테두리, `onAccent` 글자)
  - `danger` 코랄 `#FF6B5A` — 삭제·경고 **전용**.
- 텍스트는 `textPrimary/textSecondary/textMuted` 세 단계. 크로스페이드
  (`PrimaryText`)는 폐기 — 배경이 항상 어두우므로 밝은 글자 하나뿐.
- 예외: **주간 청구서 영수증만 밝은 종이**(bill_screen의 `_Paper`). 공유되는
  이미지라 이미지 단독으로 성립해야 한다 (§6.5).

### 5.2 물성 — 3D 압출
듀오링고의 시그니처는 눌리면 내려앉는 버튼이다. 이 앱에서는
**blur 0의 solid offset shadow**(`UnwindDepth.base` = 4pt)로 구현한다 —
§11 "블러 금지"와 충돌하지 않는 유일한 입체 표현이다. `UnwindPressable`이
이 물성과 햅틱을 한꺼번에 담당하며, 누를 자리는 미리 비워 둬 레이아웃이
흔들리지 않는다.

### 5.3 타이포 · 간격
- `UnwindType` — 듀오링고식으로 무겁다: display/title **w800**,
  label/button w700~800, body w500. 가변 폰트가 확실히 굵은 인스턴스를 쓰도록
  `FontVariation('wght')`를 직접 지정한다 (fontWeight만 주면 가짜 볼드 위험).
- `UnwindRadius` xs8/sm12/md16/lg24/xl32 — 전반적으로 둥글고 두툼하게.
- `UnwindStroke.base` = 2pt — 듀오링고는 얇은 선을 쓰지 않는다.
- 간격·모션은 `UnwindSpacing`/`UnwindMotion`. **하드코딩 금지.**

### 5.4 햅틱 — 모든 인터랙션에 붙는다
- `core/haptics/haptics.dart`가 의미 단위 어휘를 정의한다:
  `tap` / `selection` / `toggle(on:)` / `success` / `warning` / `error` /
  `sheetOpen·Close` + 연출용(`light/medium/heavy/tensionTick`).
- **등을 끄는 촉감이 이 앱에서 가장 세다**: `switchOff()` = medium → 55ms →
  heavy (개정 2026-08-12). 진짜 벽 스위치를 내리는 무게감이어야 한다.
  다시 켜는 쪽은 `tadak()` = light → 45ms → medium으로 가볍다.
- **화면이 `HapticFeedback`을 직접 부르지 않는다.** `UnwindPressable`이
  `UnwindHapticKind`를 받아 대신 쏘고, `UnwindHapticsScope`(main.dart에서 주입)가
  설정의 hapticsEnabled를 트리 전체에 흘린다. 컴포넌트를 쓰면 햅틱은 공짜다.
- 연출 시퀀스(소등 도미노·전등 줄)만 화면이 직접 `hapticsProvider`를 쓴다.

### 5.5 컴포넌트 — `lib/ui/`
화면 코드는 `import '../../ui/ui.dart';` 하나면 된다.
**새 UI를 만들기 전에 여기부터 본다. 없으면 여기에 만들고 쓴다.**

| 컴포넌트 | 용도 |
|---|---|
| `UnwindPressable` | 물성 원자 — 3D 압출 + 햅틱 + Semantics |
| `UnwindButton` | primary/secondary/danger/ghost · CTA 56pt, small 44pt |
| `UnwindIconButton` | plain/filled/accent — 항상 44pt 이상 |
| `UnwindCard` · `UnwindSectionLabel` · `UnwindDivider` | 면과 구분 |
| `UnwindTodoTile` | 할 일 하나 = 등 하나 (타일 + 벽 스위치) |
| `UnwindLampSwitch` / `UnwindToggle` | 세로 벽 로커 / 가로 설정 토글 |
| `UnwindTextField` | 포커스 시 테두리가 앰버로 |
| `UnwindChip` | 선택 알약 (반복·시간·자동 미루기) |
| `UnwindSheet` + `showUnwindSheet` | 바텀시트 (§9.4 320ms) |
| `showUnwindConfirm` / `showUnwindActions` | 확인·선택 (Cupertino 시트 대체) |
| `showUnwindToast` | 상단 푸시형 토스트 (`actionLabel`/`onAction`으로 되돌리기) |
| `UnwindScreen` + `UnwindHeader` | 화면 껍데기 (다크 배경·상태바·기본 글자) |

검증: 설정 > **Design gallery (dev)** 에서 전 변형을 한 화면으로 본다.
컴포넌트를 추가하면 갤러리에도 추가할 것.

### 5.6 성능·접근성 (불변)
- **§11 블러 금지.** 발광·그림자는 gradient 또는 blur 0 오프셋으로 그린다.
  (BoxShadow blur는 스위치 인디케이터 같은 소형 요소만 예외.)
- **§12**: 터치 타깃 44pt(`UnwindTouch.minTarget`), 대비 4.5:1
  (`test/core/palette_test.dart`가 팔레트 전 조합을 자동 검증),
  Reduce Motion 시 장식 애니메이션 정지, 제스처(당기기)엔 Semantics 대체 액션.

## 6. Lumi (캐릭터) — widgets/lumi/

렌더 계층: `LumiView`(앱 계약: LumiState) → `GhostView`(Rive 브리프 계약)
→ `.riv` 있으면 Rive / 없으면 **`GhostPainterView`가 실제 렌더러** (현재 .riv 없음).

**하이브리드 렌더 (2026-08-12 현행)**: 몸통(실루엣·음영·아웃라인)은
`assets/images/ghost_body.png`를 그리고, 얼굴(눈·눈꺼풀·입·볼)과 소품·zzz는
Dart 코드가 그 위에 그린다. `design_variant.dart`의 `kLumiBodyStyle` 한 줄로
painted(전부 코드)로 롤백 가능. PNG의 불투명 영역(`kGhostBodySrc*`)을
캐릭터 좌표계 세로 py(98)~py(425)에 균등 스케일로 정합한다 — 몸통 아트를
교체하면 이 측정값만 갱신하면 된다(**이미지 좌표는 top-down**; Y축을
뒤집어 재면 머리 꼭대기가 잘리는 사고가 실제로 있었다). 이미지 모드에선
밑단 물결 애니메이션이 없다(정적 아트).

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

### 디자인 규칙 (2026-08-12 현행)
- 실루엣(painted 모드 기준, image 모드는 PNG가 이 형태로 그려짐): 정원에
  가까운 **반원 돔**(이마 좁음, 정수리 살짝 봉긋) + 머리부터 넓은 각으로
  계속 벌어지는 **트럼펫형 스커트**(위→아래로 균일하게 플레어) + 옆선이
  각 없이 감아 도는 코너 스캘럽 2개 + 굵고 적은(2개, 애니메이션 담당) 가운데
  물결. 팔은 옆선에서 살짝 아래로 기운 **얇고 긴 캡슐**(귀처럼 안 보이게
  위로 기울이지 않는 게 핵심).
- 셰이딩: 흰→라벤더 수직 그라데이션, 좌우 하단의 라벤더·블루 음영,
  중앙 광택과 정수리 하이라이트, 옅은 분홍 볼터치.
- 눈은 **솔리드 잉크 세로 타원**(홍채·동공 없음, 레퍼런스 그대로) — 얼굴
  여백 확보를 위해 작게(기본 10×16, `assets/rive/svg/eye_*.svg`와 동일
  좌표). 입도 기본은 작게(혀 보이는 미소 30×26 상당)이고, **하품만 예외적
  으로 과장되게 크다** — 그래야 "진짜 하품"이 읽힌다.
- 좌표계: `k = size/500 * 1.20`, `px()/py()`가 SVG 500 캔버스 좌표를
  캔버스에 매핑한다. `assets/rive/svg/*.svg`(body/eye/eyelid/mouth_*)가
  painted 몸통·얼굴과 동일 좌표를 공유하는 소스 — Rive 리깅 시 그대로 쓴다.
- 아웃라인 잉크 `#1E1A2E`, 몸통 4.2u.
- 이벤트: checkOff(통통) / allDone(잠들기) / wakeUpHappy(기상 기지개) /
  **poke(톡 건드리기)** — `eventTick` 증가로 같은 이벤트 연속 발사.
- **톡 건드리기 (개편 2026-08-12)**: 홈에서 Lumi를 탭하면 반응한다.
  **어떤 반응인지는 화면이 아니라 렌더러가 자기 모드를 보고 고른다** —
  화면은 이벤트만 쏘고 햅틱만 맞춰 준다.
  - 깨어 있음(낮·말똥말똥) → **간지럼**: 몸을 부르르 떨고(5.5주기, 감쇠),
    눈이 ∩ ∩로 접히고, 입이 활짝 벌어지고 볼이 붉어진다. 1.3초.
  - 졸림(nightAwake) → **실눈 두리번**: 오른쪽 눈만 겨우 뜨고(목표 눈꺼풀
    0.34, 왼쪽은 0.72로 거의 감김) 좌 → 우 → 정면으로 천천히 훑은 뒤 다시
    감는다. 고개도 시선을 조금 따라간다. 2.2초.
  - **잠들었으면 무반응** — 애니메이션도 햅틱도 없다. 깨우지 않는 게 이 앱의
    예의다. 어댑터(`lumi_view.dart`)가 `isAsleep`이면 이벤트 자체를 막는다.
  - 검증: 설정 > Ghost demo (dev) 의 `poke (톡)` 버튼 + 모드 칩 조합.
- 금지: 화난 표정. (찡그림은 2026-08-09부터 밤 눈부심에 한해 허용.)
- `mode == null`이면 레거시(brightness→졸림) — 온보딩이 이 모드를 쓴다.

## 7. 홈 화면 구성 (today_screen.dart, 위→아래)

1. 설정 아이콘 + 날짜 타이틀("Today" / 과거면 "Aug 7") + 미확인 청구서 배지
2. Lumi (고정 높이 136pt, size 118) — **탭하면 반응한다** (§6 톡 건드리기)
3. 체크리스트 — `UnwindTodoTile`: 좌 텍스트(완료 시 삭선), 우 벽 로커 스위치.
   켜진 등은 **앰버 테두리**로만 구분한다 (타일이 빛을 흉내내지 않는다 — 빛의
   총량은 CornerGlow의 몫). 스위치=토글, 행 탭=편집 시트, 롱프레스·왼쪽
   스와이프=삭제. 취침 중 스위치 ON = **깨우기(undo)**.
   **삭제는 두 경로가 같은 함수를 탄다**(`_delete`) — 롱프레스든 스와이프든
   반복 항목이면 **반드시** 단일/현재 이후 전체를 먼저 묻는다(스와이프가 이
   확인을 건너뛰던 버그를 2026-08-12에 고쳤다. 스와이프에서 취소하면
   `confirmDismiss`가 false를 돌려 항목이 제자리로 돌아온다).
   반복 단건 삭제는 `deferred` tombstone을 남겨 다음 전개 때 같은 회차가
   되살아나지 않게 한다.
   지운 뒤에는 **되돌리기가 달린 상단 토스트**를 띄운다 —
   `TodoRepository.remove/removeRecurringFrom`이 `TodoUndo` 콜백을 돌려주고
   (삭제 방식마다 되돌리는 법이 달라 지식을 저장소에 가둔다), peak까지 삭제
   직전 값으로 복원한다.
4. 하단 행 — 좌: **최근 30일 스트립**(가로 스크롤, reverse라 오늘이 항상 오른쪽
   끝), 우: **Bill 버튼**(`assets/images/bill.png`, 래퍼 없음). 스트립 셀 =
   정방형 창(그날의 조도 색) + 그날 밤 Lumi의 눈(밝을수록 졸린 실눈 / 소등이면
   감은 눈, **기록 있는 완주 날엔 스마일**). 라벨 "8.2"(월.일). 탭 = 날짜 열람.
5. FAB — 앰버 라운드 스퀘어 `UnwindIconButton(accent)`. 과거 열람 중엔 그
   날짜로 추가.
6. 전등 줄(PullCord, 우측 상단에서 늘어짐) — 당기면 70ms 도미노 소등 시퀀스
   (§9.3: 절대 동시에 끄지 않는다, 마지막 등 후 500ms 정적). 히트 영역은
   painter.hitTest로 제한(리스트 가림 방지).
   **놓으면 진짜 줄처럼 논다 (개편 2026-08-12)**: `flutter/physics`의
   [SpringSimulation]으로 두 축을 적분한다 — 세로는 원위치를 **지나쳐** 위로
   튀었다가 통통 잦아들고(`cordRecoil`, ζ≈0.34, 위로 20px 제한), 가로는 느린
   진자로 흔들린다(`cordSway`, 주기 ≈1s). 줄 중간은 구슬 변위의 60%만
   움직여 자연스러운 호를 그리고, 구슬은 접선 방향으로 조금 더 실린다.
   원위치를 처음 지나칠 때 아주 가벼운 틱 하나.
   ⚠️ 이전 구현은 `max(0, spring.value)`로 **오버슈트를 잘라내** 튕김이
   보이지 않았다. 물리는 `test/features/pull_cord_test.dart`가 지킨다.
7. 상단 토스트(`showUnwindToast`)는 **삭제 되돌리기**에만 쓴다. 항목 추가
   토스트는 2026-08-12에 제거했다 — 시트가 닫히고 등이 하나 늘어나는 것이
   이미 피드백이다.
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
- 입력 시트 (개정 2026-08-12): 위→아래로 **역할별로 영역이 나뉜다** —
  ① 제목(테두리 없는 큰 입력) + `Add a note`, ② **시간**(값 행 — 탭하면 인라인
  피커), ③ **자동 미루기**(토글 행 + 설명 캡션), ④ **반복**(섹션 라벨 + 칩 그룹,
  `No repeat` 포함). 구획은 `UnwindDivider`와 넉넉한 여백으로 구분한다.
  칩은 **상호배타 선택**에만 쓴다 — 켜고 끄는 값에 칩을 쓰면 체크박스처럼
  보여서 역할이 흐려진다.
  키보드 위 바는 좌 달력 아이콘 / 중앙 날짜 이동 / 우 **화살표 저장 CTA**
  (제목이 비면 비활성). **저장하면 키보드와 함께 시트도 닫힌다** — 확인
  토스트는 없앴다(방에 등이 하나 늘어난 것이 곧 피드백). `showUnwindToast`는
  다른 용도를 위해 디자인 시스템에 남아 있다.
  편집 중 날짜 변경 시 해당 Todo를 새 날짜의 마지막 순서로 이동한다.
  자동 미루기와 반복은 상호 배제된다. 목록은 시간 있음(이른 순) → 시간
  없음(sortIndex 순)으로 정렬한다. 취침 후 기본 날짜는 내일.

## 9. 개발용 기능 (배포 전 제거 대상)

- 설정 > **Ghost demo (dev)** — 모든 모드/활동/이벤트 프리뷰 칩. 캐릭터 작업 시
  여기서 검증하는 것이 가장 빠르다.
- 설정 > **Design gallery (dev)** — `lib/ui/` 컴포넌트 전수 프리뷰. 디자인
  작업 시 여기서 검증한다.
- 설정 > **Full reset (dev)**, 홈의 **Bill 버튼은 현재 더미 데이터**
  (`_openDummyBill` — 지난주 가짜 청구서).
- `features/today/m0_prototype_screen.dart` — 온보딩 2단계가 재사용 (보존).

## 10. 검증 루틴

1. `flutter analyze` — 0 이슈 유지.
2. `flutter test` — **91개** 전부 통과가 기준선 (v2에서 램프 테스트 5개를
   팔레트 대비 7개 + 컴포넌트 계약 8개 + 삭제/되돌리기 2개 + 전등 줄 물리
   4개 + Lumi 반응 1개로 교체). UI 변경 시 위젯 테스트가 히트
   영역 겹침·오버플로 같은 실제 버그를 잡아 온 전적이 있다.
   시트/오버레이를 여는 위젯 테스트는 `pump()` 한 번 뒤에 `pump(duration)`을
   해야 한다 (누름 상태 setState가 첫 프레임을 먹는다).
3. 시뮬레이터 확인 — 캐릭터는 Ghost demo에서, 상태 흐름은 홈에서.
   (Claude Code는 `flutter run` 백그라운드 + `kill -USR1 <pid>`로 hot reload.)

## 11. 이력·문서

- `docs/prd-amendments.md` — PRD 개정 기록 (컨펌된 것만).
- `README.md` — 셋업 안내.
- PRD 원문(`unwind-prd-v1.md`)·Rive 브리프는 **저장소에 없다** — 코드 주석의
  §번호가 그 조항을 가리키며, 위 §5·§8의 요약이 현행 규칙이다.
- 큰 개편 이력: 2026-08-07 darkGlow 컨셉/벽 스위치/깨우기, 2026-08-08 카와이
  캐릭터 개편·생활 모드(일과/밤)·하단 스트립, 2026-08-09 날짜 열람(viewed)·
  30일 스트립·반원 실루엣·손에 쥔 소품·밤 표정(찡그림·하품·처진 입),
  2026-08-12 트럼펫 스커트·캡슐 팔 재조정·눈/입 축소(하품만 과장)·
  `assets/rive/svg/` 소스 세트·몸통 PNG 하이브리드 렌더,
  **2026-08-12 디자인 시스템 v2** (조도 램프 폐기 → 고정 다크 팔레트,
  듀오링고식 3D 물성, `lib/ui/` 컴포넌트 라이브러리, 전 인터랙션 햅틱).
