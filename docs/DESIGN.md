# quickJaso — 설계 문서

## 1. 기술 선택

| 항목 | 결정 | 이유 |
|---|---|---|
| 빌드 시스템 | SwiftPM (`Package.swift`) + `scripts/build-app.sh`로 `.app` 번들 조립 | xcodegen/tuist 없음. `.pbxproj` 수작업은 깨지기 쉬움. SwiftPM은 `swift build`/`swift test`로 CI·CLI에서 재현 가능하고 Xcode에서도 그대로 열린다. |
| 최소 OS | macOS 13 (Ventura) | `Table`, `NavigationSplitView`, `@MainActor` 안정. |
| Swift | 5.9+ 언어 모드 (Swift 6 strict concurrency는 비활성) | 컴파일 안정성 우선. |
| Finder 통합 | **NSServices** (앱 `Info.plist`의 `NSServices` + `NSApplication.servicesProvider`) | 별도 타깃/Automator 없이 앱 하나로 완결. Finder 우클릭 → `서비스` 하위 메뉴(항목이 적으면 컨텍스트 메뉴 하단에 직접 노출)에 표시. 파일 URL은 NSPasteboard(`public.file-url`)로 전달되므로 임의 경로 문자열·shell 실행이 없다. 다중 선택 지원. |
| 보조 진입점 | URL scheme `quickjaso://inspect`, `quickjaso://convert` (+ `file` 파라미터, percent-encoded file URL) 및 `application(_:open:)` (Finder “다음으로 열기”, 드래그 앤 드롭) | 알림 액션·재실행·개발 편의. |
| Sandbox | 기본 **비활성** (개발자 직접 배포). `Resources/quickJaso.entitlements`는 제공하고, 코드 전반은 security-scoped 접근 패턴을 사용하여 sandbox를 켜도 동작하도록 함 | Services 경유 파일 URL은 sandbox에서 접근 보장이 macOS 버전에 따라 불확실. fail-safe 우선. README에 명시. |
| 알림 | **사용 안 함** (2026-09-04 사용자 결정) | 결과 패널만으로 완결. 대신 최초 실행 시 전체 디스크 접근 권한 안내 창 표시. |
| 결과 패널 | `NSPanel`(non-activating, floating, `.hudWindow` 아님) + `NSHostingView<ResultPanelView>` | Finder 포커스를 뺏지 않음. |

### Finder 진입 흐름
```
Finder 선택 → 우클릭 → 서비스 → "Windows 호환 검사" / "Windows 호환 파일명으로 변환" (Finder가 제목순 정렬하므로 검사 항목 제목에서 "성"을 뺌)
  → macOS가 quickJaso를 (필요 시) 실행하고 servicesProvider의 @objc 메서드 호출
  → QuickActionReceiver가 NSPasteboard에서 [URL] 추출
  → QuickActionRouting이 AppState.inspect(urls) 또는 AppState.convert(urls)로 라우팅
  → InspectionViewModel / ConversionViewModel → Services 계층
  → ResultPanelController가 NSPanel 표시 (비모달)
  → "상세 보기" 등 버튼 → 메인 상세 창(ResultDetailView) 열기
```

## 2. 모듈 구성 (SwiftPM 타깃)

```
quickJaso/
├── Package.swift
├── Sources/
│   ├── QuickJasoCore/            # 순수 Foundation. UI 의존 없음. 전부 테스트 가능.
│   │   ├── Models/  (NormalizationStatus, FileItemKind, FilenameInspectionItem,
│   │   │            RenameOperation, InspectionSummary, InspectionReport,
│   │   │            ScanOptions, RiskAssessment, OperationRecord)
│   │   └── Services/(FilenameNormalizer, FileTreeScanner, RenamePlanner,
│   │                 CollisionDetector, RenameExecutor, FileAccessService,
│   │                 VolumeRiskAnalyzer, GitRepositoryDetector, ResultReportExporter,
│   │                 ConversionPipeline)
│   └── QuickJaso/                # macOS 앱 (SwiftUI + AppKit)
│       ├── App/        (QuickJasoApp, AppDelegate, AppState, AppCommands, AppSettings)
│       ├── ViewModels/ (InspectionViewModel, ConversionViewModel, ResultDetailViewModel)
│       ├── Views/      (MainWindowView, DropZoneView, ResultPanelView, ResultDetailView,
│       │                ConversionConfirmationView, RiskConfirmationView, SettingsView,
│       │                StatusBadge)
│       ├── Panels/     (ResultPanelController — NSPanel 관리)
│       ├── QuickAction/(QuickActionReceiver, QuickActionRouting)
│       └── Services/   (NotificationService)
├── Resources/
│   ├── Info.plist               # NSServices, CFBundleURLTypes, LSUIElement=NO
│   ├── quickJaso.entitlements
│   └── ko.lproj/Localizable.strings (선택)
├── Tests/QuickJasoCoreTests/
├── scripts/build-app.sh         # swift build -c release → build/quickJaso.app 조립 + ad-hoc codesign
├── docs/
└── README.md
```

## 3. 핵심 알고리즘

### 3.1 스캔 (FileTreeScanner)
- 입력: 루트 URL 목록 + `ScanOptions { followSymlinks=false, renameSymlinkItself=false, recurseIntoPackages=false, includeHidden=true, skipSystemFiles=true }`
- 각 루트에 대해 `resourceValues(forKeys:)`로 `isDirectory, isSymbolicLink, isPackage, isHidden, isUbiquitousItem, ubiquitousItemDownloadingStatus, fileResourceIdentifier, volumeIsReadOnly` 등을 읽는다.
- 재귀는 `FileManager.enumerator(at:includingPropertiesForKeys:options:)` 대신 **직접 재귀**(`contentsOfDirectory(at:includingPropertiesForKeys:options:)`)로 구현하여 symlink/package/depth를 정확히 제어한다.
- 상대 경로는 선택된 루트의 **부모**를 기준으로 계산한다 (루트 자체도 항목이며 depth 0).
- 시스템 파일 집합: `.DS_Store`, `.localized`, `Icon\r`, `.Spotlight-V100`, `.Trashes`, `.fseventsd`, `.TemporaryItems`.
- 읽기 실패 디렉터리는 `inaccessible` 항목 하나로 보고하고 계속 진행한다.
- iCloud 미다운로드(`ubiquitousItemDownloadingStatus != .current`) 또는 `NSURLIsUbiquitousItem` 확인 불가 → `skipped` + 메시지 `확인 불가 — 먼저 다운로드 필요`.

> **구현 중 확정 (2026-09-04)**: 항목 이름은 절대 URL의 `lastPathComponent`에서 얻지 않는다. Finder 서비스 pasteboard가 주는 URL은 NFD로 분해되어 있을 수 있어,
> 이미 NFC인 파일이 `needsRename` → 충돌로 오판됐다. 스캐너는 `resourceValues(forKeys: [.nameKey])`와 부모 디렉터리 목록·`fileResourceIdentifier` 대조로
> 디스크상의 실제 바이트 이름을 확정하고, 확정 불가 시 `.skipped`로 fail-safe 처리한다.

### 3.2 계획 (RenamePlanner + CollisionDetector)
1. 각 항목: `normalized = name.precomposedStringWithCanonicalMapping`. 같으면 `alreadyNFC`, 다르면 후보.
2. 후보에 대해 `plannedDestinationURL = parent.appendingPathComponent(normalized, isDirectory:)`.
3. CollisionDetector:
   - (a) 같은 부모 내 후보들의 `normalized`를 그룹핑 → 2개 이상이면 전원 `collision` (수렴 충돌).
   - (b) 같은 부모의 실제 디렉터리 목록(스캔 시 확보)에서 `normalized`와 **바이트 동일**한 이름이 존재하고 그것이 자기 자신이 아니면 `collision`.
   - (c) 목적지 URL의 `fileResourceIdentifier`를 조회해 값이 있고 원본 identifier와 **다르면** `collision`; **같으면** APFS/HFS+가 정규화 비민감으로 같은 항목을 가리키는 것이므로 rename 가능(APFS는 정규화 보존·비민감이므로 `moveItem`이 같은 inode에 대해 이름만 바꾸는 것이 허용된다). identifier 조회가 불가능하고 `fileExists`가 true면 fail-safe로 `collision`.
   - APFS에서 `moveItem(at: NFD, to: NFC)`가 “이미 존재” 오류를 낼 수 있으므로 RenameExecutor는 (c) 케이스에 한해 **2단계 rename**(임시 고유 이름 → 최종 이름)을 사용한다. 임시 이름: `.<uuid>.quickjaso-tmp` 형태이며 부모 안에서 존재하지 않음을 확인 후 사용. 1단계 성공 후 2단계 실패 시 원래 이름으로 복구 시도하고 `error`로 보고.
4. 결과 `RenamePlan { items: [FilenameInspectionItem], operations: [RenameOperation] }` — operations는 depth 내림차순(bottom-up), 같은 depth 내 경로 순.

### 3.3 실행 (RenameExecutor)
> **구현 중 확정 (2026-09-04)**: APFS에서 `FileManager.moveItem(NFD → NFC)`는 같은 디렉터리 엔트리를 가리켜 no-op으로 성공하고,
> `fileSystemRepresentation`이 경로를 NFD로 재분해하므로 Foundation만으로는 NFC 이름을 기록할 수 없다.
> 따라서 실행기는 **모든** 작업을 2단계(원본 → `.quickjaso-tmp-<UUID>` → 최종)로 수행하고, 최종 단계는 `renamex_np(..., RENAME_EXCL)`로
> 바이트 그대로 전달한다. 완료 후 `contentsOfDirectory(atPath:)`로 NFC 바이트 존재·NFD 바이트 부재를 검증하며, 실패 시 `.error`로 보고한다.
> 테스트도 경로 존재 여부가 아니라 디렉터리 엔트리의 UTF-8 바이트를 검사한다.

- operations를 depth 내림차순으로 처리. 각 op 직전에 `sourceURL`이 존재하는지, resource identifier가 계획 당시와 동일한지 재확인(외부 변경 감지). 다르면 `error: 외부에서 변경됨`.
- rename은 `FileManager.moveItem(at:to:)`. bottom-up이므로 상위 폴더 rename이 하위 op에 영향 없음. 그래도 실행 후 `resultingURL`을 기록하고, 상위 rename 후 하위 항목의 `resultingURL`은 경로 접두어 치환으로 갱신(표시용).
- 오류는 항목별로 기록, 전체 계속.
- 실행 결과에 `OperationRecord`(변환 목록, 타임스탬프)를 만들어 AppState에 최근 기록으로 보관 (undo는 TODO — 진입점만).

### 3.4 위험 분석 (VolumeRiskAnalyzer + GitRepositoryDetector)
- 대상 수 ≥100, rename 수 ≥50, 충돌 ≥1, 동기화 경로(`isUbiquitousItem` 또는 경로에 `Mobile Documents`, `Dropbox`, `OneDrive`, `Google Drive`, `CloudStorage`), 외장/네트워크(`volumeIsInternal == false`, `volumeIsLocal == false`, `volumeIsRemovable`), Git(`.git` 상위 탐색), packages 옵션 ON → `RiskAssessment { reasons: [RiskReason] }`.

## 4. 확인 흐름 (ConversionViewModel)
```
convert(urls):
  scan → plan → risk
  if !settings.skipFirstConfirmation → ConversionConfirmationView(sheet/modal 창). 취소 시 종료.
  if risk.reasons.nonEmpty → RiskConfirmationView (변경/유지/건너뜀 수 + 사유). 취소 시 종료.
  execute → ResultPanel(변환 결과)
```
검사(inspect)는 확인 없이 scan → plan → ResultPanel(검사 결과). 패널의 `NFC로 변환…`은 같은 URL로 convert 흐름 진입.

## 4.1 창 관리 (구현 중 확정)
- 메인 창은 `Window` 씬 하나만 사용(`WindowGroup` 금지: 실행마다 창이 누적됨). 모든 창 `isRestorable = false`, `NSQuitAlwaysKeepsWindows = false`를 앱 도메인에 기록.
- 실행 사유 판별: `applicationWillFinishLaunching`에서 `currentAppleEvent`가 `kAEOpenApplication`이고 `keyAELaunchedAsServiceItem`/로그인 항목 파라미터가 없을 때만 “사용자 실행”. 서비스·URL·문서 열기로 실행되면 메인 창을 숨기고 결과 패널만 표시. 보조로 1초 내 Quick Action 요청이 없을 때만 메인 창 표시.
- URL 스킴은 `application(_:open:)`으로만 수신 (kAEGetURL 핸들러 병행 시 이중 처리됨). 동일 요청은 1초 내 중복 제거.
- 확인 창(NSAlert)은 `NSApp.activate` 후 `runModal`.

## 5. 결과 패널 규칙
- 자동 닫힘(4초): 검사 패널은 항상(마우스 hover 시 취소). 변환 패널은 충돌·오류·확인불가 0 이고 변환 항목 < 10 일 때만.
- 패널은 화면 우상단, 비활성 `NSPanel`(`.nonactivatingPanel`, `level = .floating`, `hidesOnDeactivate = false`).
- 알림 없음. 최초 실행(사용자 실행·서비스 실행 모두)에 `FullDiskAccessChecker`가 허용됨이 아니면 `권한 설정 안내` 창(floating, 비모달)을 띄우고 `x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles`로 시스템 설정을 연다. 앱은 권한을 직접 변경하지 않는다.

## 6. 설정 (AppSettings, UserDefaults)
- `skipConversionConfirmation: Bool = false`
- `renameSymlinkItself: Bool = false`
- `recurseIntoPackages: Bool = false`
- `includeHiddenFiles: Bool = true`
- `hasDismissedFullDiskAccessOnboarding: Bool = false`

## 7. TODO / 향후
- Undo (OperationRecord 기반, 충돌·외부 변경 없을 때만)
- Finder “빠른 동작” 섹션에 직접 노출되는 Action Extension 타깃 (현재는 서비스 메뉴)
- Localizable.strings 기반 다국어
