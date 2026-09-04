# quickJaso — 제품 사양서 (사용자 원문 요구사항)

> 이 문서는 사용자가 제시한 요구사항을 정리한 것이다. 구현 시 반드시 준수한다.
>
> **변경 이력 (2026-09-04)**: §5·§14의 로컬 알림(UserNotifications) 기능은 사용자 결정으로 **제거**됨. 결과는 앱 자체 패널로만 표시한다. 대신 최초 실행 시 macOS 전체 디스크 접근 권한을 사용자가 직접 설정하도록 안내하는 창을 띄운다 (앱이 권한을 바꾸지 않음). 서비스 메뉴 제목은 Finder 정렬 순서 때문에 `Windows 호환 검사`로 변경(검사가 위, 변환이 아래).

## 1. 제품 목적

macOS에서 생성·관리되는 파일 및 폴더 이름을 Unicode NFC 형식으로 검사하고 필요하면 NFC로 안전하게 변경하는 도구다.
Finder에서 파일/폴더를 선택한 뒤 우클릭 Quick Action(서비스)을 실행하여 파일명을 Windows 전달에 적합한 NFC 형식으로 정리한다.

중요 원칙:
- 목표 정규화 형식은 반드시 NFC. NFKC/NFKD 사용 금지.
- 파일 내용은 절대 수정하지 않는다. 파일과 폴더의 이름만 변경한다.
- 한글만이 아니라 Unicode 전체 문자열에 대해 NFC 여부를 검사한다.
- `String.precomposedStringWithCanonicalMapping`을 NFC 변환에 사용한다.
- 파일명 전체를 NFC로 변환한다. 확장자를 분리/변경하지 않는다.
- shell command나 경로 문자열 조합에 의존하지 말고 `URL`, `FileManager`, Foundation API 중심으로 구현한다.
- Finder Sync Extension(배지)은 구현하지 않는다. Finder 전체 감시 금지.

## 2. Finder 동작 두 가지

1. `Windows 호환성 검사` — 검사만 수행, 작은 비모달 결과 패널 표시.
2. `Windows 호환 파일명으로 변환` — 내부 검사 후 안전한 항목만 자동 NFC rename, 결과 패널 표시.

### 2-1. 검사 동작
- 선택한 파일·폴더 검사. 폴더는 하위까지 재귀.
- 결과는 작은 비모달 패널. Finder 작업을 방해하지 않는다.
- 단순 결과는 toast처럼 자동 사라질 수 있으나 오류·충돌·다수 변경 가능 항목이 있으면 사용자가 닫을 때까지 유지.
- 상세는 버튼을 눌렀을 때만 상세 창으로.

검사 결과 상태:
- `Windows 호환 (NFC)` — 이미 NFC. 초록 + `checkmark.circle.fill`
- `NFC 변환 필요` — NFC 아님, 아직 미변환. 주황 + `exclamationmark.triangle.fill`
- `변환 불가 — 이름 충돌` — 빨강 + `xmark.octagon.fill`
- `변환 불가 — 접근 오류` — 권한/읽기전용/파일제공자/잠김/FS 오류. 빨강 + `xmark.octagon.fill`
- `확인 불가` — iCloud/Dropbox/OneDrive 미다운로드 등. 회색 또는 주황 + `questionmark.circle`

UI 원칙: NFC가 아니라는 이유만으로 빨간색 표시 금지. 빨강은 충돌·권한·오류에만. 색상 + 아이콘 + 텍스트를 항상 함께.

검사 결과 패널 예시:
- 제목 `Windows 호환성 검사 완료`
- `✓ Windows 호환 (NFC): 18개` / `! NFC 변환 필요: 3개` / `✕ 변환 불가: 1개` / `? 확인 불가: 0개`
- 버튼 `상세 보기` / `NFC로 변환…` / `닫기`

## 3. 변환 동작
1. 선택 항목 검사 → 2. NFC 아닌 이름 찾기 → 3. 충돌 없이 변경 가능한 것만 rename → 4. 이미 NFC는 절대 미변경 →
5. 충돌·권한 오류·읽기전용·클라우드 미다운로드·불확실 항목 절대 자동 변경 금지 → 6. 결과 간결 표시 → 7. 상세 목록 확인 가능.

정책:
- 폴더 이름도 변환 대상.
- 심볼릭 링크는 따라가지 않음. 링크 자체 이름 변경 여부는 설정 옵션(기본 OFF).
- `.app`, `.bundle`, `.framework`, `.photoslibrary` 등 package는 내부 재귀 처리 안 함. 바깥 이름만.
- `.DS_Store` 등 시스템 파일은 기본 건너뜀.
- 자동 충돌 해결 금지. 접미사 금지. overwrite 금지. 자동 병합/삭제 금지.
- 개별 오류가 있어도 전체 작업 중단 금지. 성공·유지·충돌·오류·건너뜀 모두 집계.

변환 결과 패널 예시:
- 성공: 제목 `Windows 호환 파일명으로 변환 완료`, `✓ 변환됨: 3개`, `✓ 이미 호환: 18개`, `– 건너뜀: 0개`, 설명 `선택한 파일 및 폴더 이름을 NFC 형식으로 정리했습니다.`, 버튼 `변경 내역 보기`/`닫기`
- 일부: 제목 `일부 항목만 변환했습니다`, `✓ 변환됨: 12개`, `✓ 이미 호환: 18개`, `✕ 이름 충돌: 2개`, `? 확인 불가: 1개`, 설명 `충돌하거나 접근할 수 없는 항목은 변경하지 않았습니다.`, 버튼 `문제 항목 보기`/`변경 내역 보기`/`닫기`
- 모두 NFC: 제목 `이미 Windows 호환 파일명입니다`, `검사한 24개 항목은 모두 NFC 형식입니다.`, 버튼 `닫기`

## 4. 변환 전 확인 정책
- 최초 변환 시 1회 확인 dialog: 제목 `Windows 호환 파일명으로 변환할까요?`, 본문 `선택한 항목에서 NFC가 아닌 파일 및 폴더 이름만 NFC로 변경합니다.` / `파일 내용은 변경하지 않습니다.` / `이름 충돌, 권한 오류, 동기화 중인 항목은 자동으로 건너뜁니다.`, 체크박스 `앞으로 묻지 않기`, 버튼 `취소`/`변환`.
- 위험 조건이 하나라도 있으면 (묻지 않기 설정과 무관하게) 변환 직전 확인 UI 표시:
  - 검사 대상 100개 이상
  - 실제 rename 대상 50개 이상
  - 이름 충돌 1개 이상
  - iCloud Drive/Dropbox/OneDrive 등 동기화 경로
  - 외장 디스크 또는 네트워크 볼륨
  - Git 저장소 내부로 추정
  - package 내부 재귀 변환 옵션이 켜진 경우
- 위험 확인 UI: 바뀔 항목 수, 유지될 항목 수, 건너뛸 항목 수, 위험 요약, `취소`/`계속 변환`.

## 5. 결과 표시
- 기본 결과 UI는 SwiftUI 기반 작은 비모달 패널(`NSPanel`). Finder 흐름을 막지 않음.
- 단순 성공 + 짧은 작업이면 약 5초 후 자동 사라짐 가능.
- 자동 사라짐 금지: 충돌 있음 / 접근 오류 있음 / 확인 불가 있음 / 변경 항목 10개 이상.
- `닫기` 버튼 제공.
- 로컬 알림(UserNotifications)은 보조: 긴 작업, 다른 앱 전환, 백그라운드, 설정에서 켠 경우. 제목 `NFC Filename Guard`, 본문 예 `파일명 변환 완료: 12개 변환, 2개 이름 충돌`, 액션 `결과 보기` → 상세 결과 창. 권한 거부 시에도 패널만으로 완결.

## 6. 상세 결과 화면
테이블 컬럼: 결과 / 원래 상대 경로 / 변환 후 상대 경로 / 상태 / 상세 사유.
필터: 전체 / 변환됨 / 이미 NFC / NFC 변환 필요 / 이름 충돌 / 오류·확인 불가.
기능: `Finder에서 보기`(없으면 부모 폴더), `변경 내역 복사`(텍스트), `CSV 내보내기`, `닫기`.
향후: 되돌리기(undo) — MVP에서는 작업 기록 모델과 UI 진입점만 설계하고 TODO 가능. 구현 시 충돌·외부 변경 없는 경우에만.

## 7. NFC 검사/변환 로직
```swift
let normalized = originalName.precomposedStringWithCanonicalMapping
let isNFC = (originalName == normalized)
```
- 대상 URL은 부모 URL 기준으로 생성: `parentURL.appendingPathComponent(normalizedName, isDirectory: isDirectory)`
- rename은 `FileManager.moveItem(at:to:)` 등 안전한 Foundation API.
- `try!`, force unwrap, 오류 무시 금지.
- security-scoped URL 패턴(`startAccessingSecurityScopedResource` + defer stop) 필요 시 사용.
- 재귀 변환은 반드시 plan을 먼저 만든 뒤 실행. plan에는 원본 URL, 대상 URL, 상대 경로, 깊이, 상태, 충돌 여부 포함.
- 실제 rename은 깊은 경로부터 bottom-up. rename 이후 변경된 URL 추적. 하위 경로 문자열을 미리 고정해 두고 무작정 처리 금지.
- 가능하면 file resource identifier 등으로 항목 identity 추적.
- 불확실하면 건너뛰는 fail-safe.

## 8. 충돌 판정 (변경 전 수행)
1. 같은 부모 안에 NFC 결과 이름과 같은 다른 항목이 이미 존재
2. 서로 다른 원본 이름들이 같은 NFC 결과로 수렴
3. FS가 정규화 비민감이어서 목적지 존재 여부가 애매하고 동일 항목 여부를 안전하게 판단할 수 없음
4. 변환 대상이 아닌 기존 항목과 충돌
처리: overwrite/접미사/병합/삭제 금지. 충돌 항목은 `collision`으로 보고. 나머지는 계속.

## 9. 예외 항목
- symlink 미추적, 내부 미처리, 자체 이름 변경은 옵션(기본 OFF)
- package 내부 미재귀(옵션으로 켤 수 있음, 켜면 위험 조건)
- `.DS_Store` 등 시스템 파일 건너뜀
- 숨김 파일은 기본 포함, 설정에서 제외 가능
- 읽기 전용 볼륨 / 권한 없음 → 오류 보고, 미변환
- iCloud/파일 제공자 미다운로드 → `확인 불가` / `먼저 다운로드 필요`
- Git 저장소: `.git` 상위 탐색으로 감지. Git 명령 실행/상태 변경 금지.
- 네트워크/외장 볼륨 감지 → 위험 경고 반영

## 10. 데이터 모델 (출발점)
```swift
enum NormalizationStatus: String, Codable, CaseIterable { case alreadyNFC, needsRename, renamed, collision, skipped, inaccessible, error }
enum FileItemKind: String, Codable, CaseIterable { case file, directory, symlink, package, unknown }
struct FilenameInspectionItem: Identifiable, Codable, Hashable {
    let id: UUID; let originalURL: URL; let originalRelativePath: String; let originalName: String
    let normalizedNFCName: String; var plannedDestinationURL: URL?; var resultingURL: URL?
    let kind: FileItemKind; var status: NormalizationStatus; var message: String?; var depth: Int
}
struct RenameOperation: Identifiable, Codable, Hashable { let id: UUID; let sourceURL: URL; let destinationURL: URL; let originalRelativePath: String; let depth: Int }
struct InspectionSummary: Codable, Hashable { var total, alreadyNFC, needsRename, renamed, collisions, skipped, inaccessible, errors: Int }
```

## 11. UI/접근성
- 기본 UI 언어 한국어. 권장 문구: `Windows 호환 파일명(NFC)`, `Windows 호환성 검사`, `Windows 호환 파일명으로 변환`, `Windows 호환 (NFC)`, `NFC 변환 필요`, `변환 불가 — 이름 충돌`, `변환 불가 — 접근 오류`, `확인 불가`, `변환 전 미리보기`, `변경 내역 보기`, `문제 항목 보기`, `Finder에서 보기`
- SF Symbol: 성공 `checkmark.circle.fill`, 변환 필요 `exclamationmark.triangle.fill`, 충돌/오류 `xmark.octagon.fill`, 확인 불가 `questionmark.circle`, 처리 중 `arrow.triangle.2.circlepath`
- 모든 아이콘에 accessibility label. 상태 행은 VoiceOver가 읽을 수 있게. Light/Dark 대비 충분.

## 12. 앱 구조
SwiftUI UI 코드와 파일 시스템 로직 분리. (App / Models / Services / ViewModels / Views / QuickAction / Resources / Tests)
Services: FilenameNormalizer, FileTreeScanner, RenamePlanner, RenameExecutor, CollisionDetector, FileAccessService, VolumeRiskAnalyzer, GitRepositoryDetector, ResultReportExporter, NotificationService.
ViewModels: InspectionViewModel, ConversionViewModel, ResultDetailViewModel.
Views: MainWindowView, DropZoneView, ResultPanelView, ResultDetailView, ConversionConfirmationView, RiskConfirmationView, SettingsView.
QuickAction: QuickActionReceiver, QuickActionRouting.

## 13. Finder Quick Action
- Finder에서 파일·폴더 입력(다중 선택 포함)을 받아야 함. 컨텍스트 메뉴의 “빠른 동작” 또는 “서비스”에서 실행 가능.
- 두 동작 제공. 무확인 즉시 rename 금지(1회 확인/위험 확인 규칙 준수).
- Automator workflow만 던지는 수준 금지. 앱과 연결된 완성된 흐름.
- 임의 shell command 실행이나 임의 경로 문자열 전달 방식 금지.
- 등록/활성화 방법과 제한을 README에 문서화.

## 14. 로컬 알림 — 보조 기능. Settings에서 on/off. `결과 보기` 액션 → 상세 창.

## 15. 테스트 (XCTest)
정규화: 이미 NFC 한글 → alreadyNFC / NFD 한글 → needsRename / 변환 결과 기대값 / idempotency / 결합 악센트 등 비한글 / 확장자 포함 전체 이름 유지.
파일 시스템(임시 디렉터리): NFD 파일·폴더 생성·검사 / NFC 목적지 URL 계산 / rename 후 내용 유지 / 동일 NFC 이름 존재 시 collision / 여러 NFD → 같은 NFC 수렴 충돌 / 중첩 폴더 bottom-up / symlink 미추적 / package 내부 미재귀 / 읽기 전용·접근 실패 → 오류 상태.
수동 테스트 체크리스트는 README에.

## 16. README (한국어) — 목적, NFC/NFD 차이, Windows 문제 원인, 이름만 변경, 사용법, 상태 의미, 충돌 동작, 확인 정책, 서비스 활성화, 권한/sandbox, 알림, 빌드, 테스트, 제한사항, 주의사항.

## 17. 품질 기준
- 실제 컴파일 가능한 Swift. 핵심 FS 로직 mock 금지. `try!`/force unwrap/오류 무시 금지.
- UI와 검사·계획·실행 로직 분리. fail-safe. 사전 검사 흐름 강제 금지.
