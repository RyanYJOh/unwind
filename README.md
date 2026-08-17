# Unwind

하루를 끝내는 앱. 할 일을 하나씩 지울 때마다 집의 불이 하나씩 꺼지고,
마지막 불이 꺼지면 유령 Todd가 잠든다.

- 스택: Flutter + Riverpod + Drift (로컬 온리, 서버 없음)
- **LLM/에이전트 컨텍스트: `AGENTS.md` (정본 — Cursor·Claude Code 공용)**
- 개정 이력: `docs/prd-amendments.md`
  (PRD 원문 `unwind-prd-v1.md`·Rive 브리프는 저장소 밖 — 코드의 §번호가 그 조항)

## 다른 PC에서 시작하기

필요한 것: **Flutter 3.44+ (stable)**, **Xcode(정식)**, **CocoaPods**

```bash
git clone git@github.com:RyanYJOh/unwind.git
cd unwind
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # Drift 코드젠
flutter gen-l10n                                           # i18n 코드젠
flutter test                                               # 57개 통과 확인
```

실행:
```bash
flutter run                        # 연결된 시뮬레이터/기기
flutter build ios --simulator      # 시뮬레이터용 빌드
```

폰트·drift wasm 등 에셋은 전부 저장소에 포함되어 있다.

## 구조 요약

- `lib/core/tokens/` — 색 램프(OKLab)·타이포·간격·모션 상수 (PRD §8·§9 값, 하드코딩 금지)
- `lib/domain/services/` — 조도 엔진, 청구서 계산기, 반복 전개, 롤오버
- `lib/features/` — today / week / compose / bill / settings / onboarding
- `lib/widgets/todd/` — 캐릭터. `ToddView`(앱 계약) → `GhostView`(브리프 계약)
  → `.riv` 있으면 Rive, 없으면 `GhostPainterView`(Flutter 구현)
- `lib/l10n/` — ARB (영어 기본, 한국어). 새 언어는 `app_XX.arb` 추가

## 개발용 기능 (배포 시 제거 — `TODO(unwind)` 주석 검색)

- 설정 > 완전 초기화(개발용): 온보딩 포함 첫 실행 상태로
- 설정 > Ghost demo (dev): 캐릭터 sleepiness 스크럽 + 트리거 테스트

## 남은 작업

- 실기기 감각 검증 (PRD §13 M0 승인 게이트, §11 성능: iPhone 11 프레임 드랍 0)
- Rive 캐릭터 제작 (선택 — Cadet 플랜 필요. `.riv`를 `assets/rive/ghost.riv`에
  넣으면 자동 전환)
