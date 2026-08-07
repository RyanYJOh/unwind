/// 방 디자인 변형 스위치 (개편 2026-08-07).
///
/// - [RoomDesign.darkGlow]: **기본** — 베이스는 항상 다크. 우측 상단
///   코너에서 순수한 빛이 그라데이션으로 방을 밝힌다 (조명 그림 없음).
///   체크할수록 빛이 잦아들고, 전부 체크하면 완전한 다크.
/// - [RoomDesign.ceilingLight]: 갓+전구 그림이 있는 천장 조명 버전.
/// - [RoomDesign.fluorescent]: 아이템 자체가 발광하는 형광등 패널 버전.
/// **롤백은 아래 상수 한 줄만 바꾸면 된다.**
enum RoomDesign { darkGlow, ceilingLight, fluorescent }

const kRoomDesign = RoomDesign.darkGlow;
