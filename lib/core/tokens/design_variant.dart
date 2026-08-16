// 방 디자인 (개편 2026-08-12, 디자인 시스템 v2).
//
// 베이스는 **항상 다크**다. 남은 빛은 우측 상단 CornerGlow가 표현하고,
// 아이템 타일은 빛을 흉내내지 않는다 (앰버 테두리로만 켜짐을 알린다).
//
// 이전 변형(ceilingLight = 갓+전구 그림, fluorescent = 발광 패널)은
// 램프 팔레트에 묶여 있어 v2에서 제거했다. 되살리려면 git 히스토리의
// `RoomDesign` enum과 `widgets/ceiling_light.dart`를 참조할 것.

/// Todd 몸통 렌더 방식 (개편 2026-08-12).
///
/// - [ToddBodyStyle.image]: **기본** — 몸통(실루엣+음영+아웃라인)은
///   `assets/images/ghost_body.png`, 얼굴(눈·눈꺼풀·입·볼)과 소품은
///   지금처럼 Dart 코드가 그 위에 그린다. 몸통 아트를 코드 밖에서
///   교체할 수 있고, 이미지에는 §11 제약 없이 부드러운 음영을 구울 수 있다.
/// - [ToddBodyStyle.painted]: 이전 방식 — 몸통까지 전부 CustomPainter.
/// **롤백은 아래 상수 한 줄만 바꾸면 된다.**
enum ToddBodyStyle { painted, image }

const kToddBodyStyle = ToddBodyStyle.image;

/// ghost_body.png 안에서 유령이 차지하는 불투명 영역 (픽셀, 측정값).
/// 렌더 시 이 영역을 캐릭터 좌표계에 정합시킨다.
///
/// 이미지 좌표(top-down) 기준이다 — 측정 시 Y축을 뒤집으면 머리 꼭대기가
/// 잘린다(2026-08-12 실제로 겪은 버그: T를 32로 잡아 돔 16~32행이 날아갔다).
/// 아트를 교체하면 알파 > 4인 픽셀의 bbox를 다시 재서 갱신할 것.
const kGhostBodyAsset = 'assets/images/ghost_body.png';
const kGhostBodySrcL = 45.0;
const kGhostBodySrcT = 16.0;
const kGhostBodySrcR = 991.0;
const kGhostBodySrcB = 993.0;
