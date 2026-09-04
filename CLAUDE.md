# quickJaso — 작업 규칙

## 역할 분담 (필수)

이 프로젝트는 **Claude와 Codex가 역할을 나누어** 작업한다.

### Claude가 직접 수행하는 일
- 요구사항 분석, 설계, 아키텍처 결정, 구현 계획 수립
- 문서 작성 및 수정: README, 설계 문서, ADR, 주석 정책, CLAUDE.md, `docs/` 이하 파일
- 코드 리뷰 결과 해석, 문제 진단, 우선순위 판단
- 사용자와의 커뮤니케이션 및 최종 보고

### Codex에 반드시 위임하는 일
- **소스 코드의 생성·수정·삭제** (테스트 코드, 설정 파일, 빌드 스크립트 포함)
- 버그 수정, 리팩터링, 의존성 추가 등 코드베이스를 변경하는 모든 구현 작업

위임 방법:
- `codex:rescue` 스킬 또는 `codex-rescue` 서브에이전트를 사용한다.
- Claude는 Codex에 넘기기 전에 **무엇을, 왜, 어떤 제약으로** 구현할지 명확한 지시문을 작성한다.
  (대상 파일, 기대 동작, 검증 방법, 건드리지 말아야 할 범위를 포함)
- Codex 작업이 끝나면 Claude가 결과를 검토하고, 문제가 있으면 수정 지시를 다시 Codex에 보낸다.

### 금지 사항
- Claude가 Edit/Write/sed 등으로 소스 코드를 직접 작성하거나 고치지 않는다.
  예외: 위 "Claude가 직접 수행하는 일"에 해당하는 문서 파일(`*.md`, `docs/`)만 직접 편집 가능.
- 코딩 요청을 받았을 때 "간단해 보인다"는 이유로 위임을 건너뛰지 않는다.

## 작업 흐름
1. 사용자 요청 접수 → Claude가 설계/계획 정리 (필요 시 문서화)
2. 구현 항목을 Codex 지시문으로 변환 → Codex 위임
3. Codex 결과 검토 → 필요 시 재위임
4. 사용자에게 결과 보고

## 프로젝트 정보
- 목적: macOS 파일·폴더 이름을 Unicode NFC로 검사·변환하는 네이티브 앱 (Finder 서비스 연동). 요구사항은 `docs/SPEC.md`, 설계는 `docs/DESIGN.md`.
- 기술 스택: Swift 5 언어 모드, SwiftPM (`Package.swift`), macOS 13+, SwiftUI + AppKit(NSPanel/NSServices), XCTest.
  - `Sources/QuickJasoCore`: Foundation 전용 핵심 로직 (UI 의존 금지)
  - `Sources/QuickJaso`: 앱 타깃
  - `Tests/QuickJasoCoreTests`: `swift test`
  - `scripts/build-app.sh`: `build/quickJaso.app` 번들 조립 (Info.plist의 NSServices로 Finder 서비스 등록)
- 검증 명령: `swift build`, `swift test`, `./scripts/build-app.sh`. Codex 샌드박스에서는 `--disable-sandbox`가 필요할 수 있으며 GUI 실행 검증은 Claude가 직접 수행한다.
- 주의: APFS에서 NFD→NFC rename은 Foundation `moveItem`으로는 반영되지 않는다. `RenameExecutor`의 2단계 + `renamex_np` 경로를 유지하고, 테스트는 디렉터리 엔트리 바이트를 검사해야 한다.
