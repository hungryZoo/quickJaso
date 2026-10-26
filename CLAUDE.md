# quickJaso — 작업 규칙

## 개발 주체
- 설계, 구현, 테스트, 문서 작성 모두 Claude가 직접 수행. 소스 코드도 Edit/Write로 직접 수정.
- Codex(`codex:rescue`)는 사용자가 요청할 때 또는 원인 진단이 막혔을 때 보조 의견 용도로만 사용. 기본 위임 대상 아님.

## 작업 흐름 (4단계 파이프라인)
1. 요청 접수 후 설계와 계획 정리 (필요 시 `docs/` 문서화)
2. 구현과 테스트 코드 작성
3. `swift build`, `swift test`, `./scripts/build-app.sh` 검증, 필요 시 GUI 실행 확인
4. 사용자에게 결과 보고

## 관련 스킬 (agents-dev-skills)
- 설치 안내: `homebrew-install-docs` (cask, 전체 이름 명령, xattr 3줄 블록)
- README: `readme-wiki-style`
- 릴리스: `release-notes` (`.github/release-notes/v<version>.md`)

## 프로젝트 정보
- 목적: macOS 파일과 폴더 이름을 Unicode NFC로 검사 및 변환하는 네이티브 앱 (Finder 서비스 연동). 요구사항은 `docs/SPEC.md`, 설계는 `docs/DESIGN.md`.
- 기술 스택: Swift 5 언어 모드, SwiftPM (`Package.swift`), macOS 13+, SwiftUI + AppKit(NSPanel/NSServices), XCTest.
  - `Sources/QuickJasoCore`: Foundation 전용 핵심 로직 (UI 의존 금지)
  - `Sources/QuickJaso`: 앱 타깃
  - `Tests/QuickJasoCoreTests`: `swift test`
  - `scripts/build-app.sh`: `build/quickJaso.app` 번들 조립 (Info.plist의 NSServices로 Finder 서비스 등록)
- 검증 명령: `swift build`, `swift test`, `./scripts/build-app.sh`. GUI 실행 검증은 `build/quickJaso.app` 실행으로 확인.
- 주의: APFS에서 NFD→NFC rename은 Foundation `moveItem`으로는 반영되지 않는다. `RenameExecutor`의 2단계 + `renamex_np` 경로를 유지하고, 테스트는 디렉터리 엔트리 바이트를 검사해야 한다.
