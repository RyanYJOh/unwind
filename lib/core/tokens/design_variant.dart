/// 방 디자인 변형 스위치 (개편 2026-08-07).
///
/// - [RoomDesign.ceilingLight]: 우측 상단 천장 조명이 방을 밝힌다.
///   아이템은 벽 스위치 — 하나씩 끄면 천장 조명의 조도가 낮아진다.
/// - [RoomDesign.fluorescent]: 이전 디자인 — 아이템 자체가 발광하는
///   형광등 패널. **롤백은 아래 상수 한 줄만 바꾸면 된다.**
enum RoomDesign { ceilingLight, fluorescent }

const kRoomDesign = RoomDesign.ceilingLight;
