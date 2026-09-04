# quickJaso — Windows 호환 파일명(NFC) 검사·변환 도구

macOS에서 만든 파일·폴더 이름을 **Unicode NFC** 형식으로 검사하고, 필요하면 안전하게 NFC로 바꿔 주는 네이티브 macOS 앱입니다.
Finder에서 파일을 선택한 뒤 우클릭 → **서비스** 메뉴에서 `Windows 호환 검사` / `Windows 호환 파일명으로 변환`을 바로 실행할 수 있습니다.

> **핵심 원칙** — 변환은 빠르게, 실패는 안전하게, 결과는 작고 명확하게.
> 파일 **내용**은 절대 건드리지 않고, 파일·폴더의 **이름**만 바꿉니다.

[![CI](https://github.com/hungryZoo/quickJaso/actions/workflows/ci.yml/badge.svg)](https://github.com/hungryZoo/quickJaso/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/hungryZoo/quickJaso)](https://github.com/hungryZoo/quickJaso/releases/latest)
![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue)

## 설치

### 방법 1 — DMG 다운로드
1. [Releases](https://github.com/hungryZoo/quickJaso/releases/latest)에서 `quickJaso-<버전>.dmg`를 내려받습니다.
2. DMG를 열고 `quickJaso.app`을 `Applications` 폴더 아이콘으로 드래그합니다.
3. 앱을 한 번 실행합니다. (첫 실행 시 아래 "처음 실행할 때" 참고)

### 방법 2 — Homebrew
```bash
brew install --cask --no-quarantine hungryZoo/tap/quickjaso
```
`--no-quarantine`을 붙이면 다운로드 격리 속성이 붙지 않아 Gatekeeper 경고 없이 바로 실행됩니다. 붙이지 않으면 방법 1과 같은 첫 실행 절차가 필요합니다.

### 처음 실행할 때 (Gatekeeper)
이 앱은 Apple Developer ID로 서명·공증(notarization)되지 않았습니다. 브라우저로 내려받은 DMG에서 설치하면 macOS가 첫 실행을 막을 수 있습니다.

- **macOS 15 이상**: 앱을 한 번 실행해 경고를 닫은 뒤 **시스템 설정 → 개인정보 보호 및 보안** 맨 아래의 **그래도 열기**를 누릅니다.
- **macOS 13~14**: Finder에서 앱을 **우클릭 → 열기**를 선택합니다.
- 또는 터미널에서 격리 속성을 제거합니다.

```bash
xattr -dr com.apple.quarantine /Applications/quickJaso.app
```

이 절차가 필요한 이유와 없앨 수 있는 방법은 [16. 알려진 제한사항](#16-알려진-제한사항)을 참고하세요.

---

## 목차

1. [무엇을 해결하나요?](#1-무엇을-해결하나요)
2. [NFC와 NFD의 차이](#2-nfc와-nfd의-차이)
3. [왜 Windows로 보낼 때 문제가 생기나요?](#3-왜-windows로-보낼-때-문제가-생기나요)
4. [이 앱은 이름만 바꿉니다](#4-이-앱은-이름만-바꿉니다)
5. [사용법 — Windows 호환성 검사](#5-사용법--windows-호환성-검사)
6. [사용법 — Windows 호환 파일명으로 변환](#6-사용법--windows-호환-파일명으로-변환)
7. [결과 상태와 색상·아이콘 의미](#7-결과-상태와-색상아이콘-의미)
8. [이름 충돌 시 동작](#8-이름-충돌-시-동작)
9. [변환 전 확인 정책](#9-변환-전-확인-정책)
10. [Finder 서비스(빠른 동작) 활성화 방법](#10-finder-서비스빠른-동작-활성화-방법)
11. [권한, Sandbox, security-scoped URL](#11-권한-sandbox-security-scoped-url)
12. [전체 디스크 접근 권한 안내](#12-전체-디스크-접근-권한-안내)
13. [빌드 방법](#13-빌드-방법)
14. [테스트 실행 방법](#14-테스트-실행-방법)
15. [수동 테스트 체크리스트](#15-수동-테스트-체크리스트)
16. [알려진 제한사항](#16-알려진-제한사항)
17. [주의사항](#17-주의사항)
18. [프로젝트 구조](#18-프로젝트-구조)

---

## 1. 무엇을 해결하나요?

macOS(특히 예전 HFS+ 시절부터 이어진 관행)에서는 한글 파일명이 **NFD**(자소 분리형)로 저장되는 경우가 많습니다.
macOS 안에서는 정상적으로 보이지만, 이 파일을 Windows·NAS·압축 파일·Git·일부 동기화 서비스로 옮기면
`한글.txt`가 `ㅎㅏㄴㄱㅡㄹ.txt`처럼 자소가 분리되어 보이거나, 같은 이름의 파일이 두 개로 인식되는 문제가 생깁니다.

quickJaso는 선택한 파일·폴더(하위 포함)의 이름이 NFC인지 검사하고, NFC가 아닌 이름만 골라 NFC로 바꿔 줍니다.

## 2. NFC와 NFD의 차이

| 형식 | 설명 | 예 (`한`) |
|---|---|---|
| **NFC** (Normalization Form C) | 조합 가능한 문자를 하나의 완성형 코드로 합친 형태 | `U+D55C` (1 코드포인트) |
| **NFD** (Normalization Form D) | 문자를 기본 자소로 분해한 형태 | `U+1112 U+1161 U+11AB` (3 코드포인트) |

두 형식은 화면에서는 똑같이 `한`으로 보이지만 바이트가 다릅니다.
이 앱은 **NFC만** 목표로 하며, 호환성 분해까지 수행하는 NFKC/NFKD는 사용하지 않습니다(예: `①`이 `1`로 바뀌는 일이 없음).

한글만이 아니라 결합 악센트(`é` = `e` + `◌́`) 등 **모든 Unicode 문자열**에 대해 NFC 여부를 검사합니다.

## 3. 왜 Windows로 보낼 때 문제가 생기나요?

- Windows(NTFS)는 파일명을 정규화하지 않고 **바이트 그대로** 저장·비교합니다. NFD 이름은 그대로 자소 분리 상태로 보입니다.
- 많은 압축 프로그램, SMB/NAS, 서버, 버전 관리 도구도 정규화를 하지 않아 NFC `한글.txt`와 NFD `한글.txt`를 **서로 다른 파일**로 취급합니다.
- 반면 macOS APFS는 정규화 **비민감**(insensitive)·**보존**(preserving)이라 어느 쪽으로 저장돼 있어도 같은 파일로 찾아 주기 때문에, macOS 안에서는 문제가 드러나지 않습니다.

## 4. 이 앱은 이름만 바꿉니다

- 파일 내용, 수정 시각, 확장 속성은 건드리지 않습니다. `FileManager.moveItem(at:to:)`로 **같은 부모 폴더 안에서 이름만** 바꿉니다.
- 확장자를 분리하거나 바꾸지 않습니다. 파일명 전체를 하나의 문자열로 NFC 변환합니다.
- 이미 NFC인 항목은 절대 건드리지 않습니다.
- 충돌·권한 오류·클라우드 미다운로드 등 불확실한 항목은 **건너뜁니다**(fail-safe).

## 5. 사용법 — Windows 호환성 검사

1. Finder에서 파일 또는 폴더를 하나 이상 선택합니다.
2. 우클릭 → **서비스** → **Windows 호환 검사**를 선택합니다.
   (서비스 항목이 적으면 컨텍스트 메뉴 하단에 바로 표시되기도 합니다.)
3. 화면 우상단에 작은 결과 패널이 나타납니다. 폴더는 하위 항목까지 재귀적으로 검사합니다.

```
Windows 호환성 검사 완료
✓ Windows 호환 (NFC): 18개
! NFC 변환 필요: 3개
✕ 변환 불가: 1개
? 확인 불가: 0개
[상세 보기] [NFC로 변환…] [닫기]
```

- **상세 보기**: 항목별 결과 테이블(상세 결과 창)을 엽니다.
- **NFC로 변환…**: 같은 대상에 대해 변환 흐름을 시작합니다.
- 검사는 파일 시스템을 전혀 변경하지 않습니다.
- 검사 결과 패널은 4초 후 자동으로 닫힙니다(마우스를 올리면 유지). 변환 결과 패널은 충돌·오류·확인 불가 항목이 있거나 10개 이상 변경됐을 때는 닫을 때까지 유지되고, 그 외에는 4초 후 닫힙니다.

앱 창(Dock 아이콘 클릭 또는 `⌘O`)에서 파일을 드래그 앤 드롭해도 같은 검사를 실행할 수 있습니다.

## 6. 사용법 — Windows 호환 파일명으로 변환

1. Finder에서 파일 또는 폴더를 선택합니다.
2. 우클릭 → **서비스** → **Windows 호환 파일명으로 변환**을 선택합니다.
3. (최초 1회 또는 위험 조건일 때) 확인 창에서 **변환**/**계속 변환**을 누릅니다.
4. 결과 패널이 표시됩니다.

앱은 내부적으로 `검사 → 계획(충돌 판정) → 깊은 경로부터 rename → 결과 집계` 순서로 동작합니다.
사전에 “검사”를 먼저 실행해야 하는 것은 아닙니다.

```
일부 항목만 변환했습니다
✓ 변환됨: 12개
✓ 이미 호환: 18개
✕ 이름 충돌: 2개
? 확인 불가: 1개
충돌하거나 접근할 수 없는 항목은 변경하지 않았습니다.
[문제 항목 보기] [변경 내역 보기] [닫기]
```

## 7. 결과 상태와 색상·아이콘 의미

| 상태 | 색 | 아이콘 | 의미 |
|---|---|---|---|
| Windows 호환 (NFC) | 초록 | `checkmark.circle.fill` | 이미 NFC. 변경 없음 |
| Windows 호환으로 변환됨 | 초록 | `checkmark.circle.fill` | 이번 작업에서 NFC로 변경됨 |
| NFC 변환 필요 | 주황 | `exclamationmark.triangle.fill` | NFC가 아님. (검사 모드) 충돌 없이 변환 가능할 수 있음 |
| 변환 불가 — 이름 충돌 | 빨강 | `xmark.octagon.fill` | NFC로 바꾸면 같은 폴더의 다른 항목과 이름이 겹침 |
| 변환 불가 — 접근 오류 | 빨강 | `xmark.octagon.fill` | 권한 부족, 읽기 전용 볼륨, 파일 시스템 오류 등 |
| 확인 불가 | 회색 | `questionmark.circle` | iCloud/Dropbox 등에서 아직 내려받지 않았거나 상태를 확인할 수 없음 |

- **NFC가 아니라는 이유만으로 빨간색을 쓰지 않습니다.** 빨강은 사용자가 직접 조치해야 하는 충돌·권한·오류에만 사용합니다.
- 상태는 항상 **색상 + 아이콘 + 텍스트**로 함께 표시하며, 모든 아이콘에 VoiceOver 레이블이 있습니다.

## 8. 이름 충돌 시 동작

다음 경우를 충돌로 판정하며, 실제 변경 **전에** 계획 단계에서 검사합니다.

1. 같은 부모 폴더에 NFC 변환 후 이름과 같은 **다른** 항목이 이미 있음
2. 서로 다른 원본 이름들이 NFC 변환 뒤 **같은 이름으로 수렴**함
3. 파일 시스템이 NFC/NFD를 구별하지 않아 목적지 존재 여부가 애매하고, 같은 항목인지 안전하게 판단할 수 없음
4. 변환 대상이 아닌 기존 항목과 이름이 겹침

충돌 항목에 대해 앱은 **절대** 덮어쓰기, `- 2` 같은 접미사 부여, 병합, 삭제를 하지 않습니다.
해당 항목만 `변환 불가 — 이름 충돌`로 보고하고 나머지 안전한 항목은 계속 변환합니다.
상세 결과 창의 **Finder에서 보기**로 충돌 항목을 열어 직접 정리한 뒤 다시 실행하세요.

> **Finder가 넘겨주는 경로 주의점** — Finder는 파일 URL의 이름을 NFD로 분해해 전달하는 경우가 있어, 이미 NFC로 바뀐 파일도 URL만 보면 NFD처럼 보입니다.
> quickJaso는 URL 문자열이 아니라 **디스크의 실제 디렉터리 항목 이름**(`.nameKey` + file resource identifier 대조)을 기준으로 판정하므로, 변환을 마친 항목을 다시 검사·변환하면 `이미 Windows 호환 파일명입니다`로 표시됩니다.
>
> **APFS 주의점** — APFS는 정규화 비민감이므로 NFD 이름과 NFC 이름이 **같은 파일**을 가리키며,
> 단순 `moveItem(NFD → NFC)`는 아무 변화 없이 성공을 반환합니다(무효 rename). 게다가 Foundation의 `fileSystemRepresentation`은
> 경로를 다시 NFD로 분해해 전달합니다. 그래서 quickJaso는 모든 rename을 **임시 ASCII 이름을 거치는 2단계**로 수행하고,
> 마지막 단계는 바이트 그대로 전달되는 `renamex_np(RENAME_EXCL)`(덮어쓰기 금지 플래그)로 처리한 뒤,
> 디렉터리 목록을 다시 읽어 **NFC 바이트가 실제로 기록됐는지 검증**합니다. 검증에 실패하면 성공으로 보고하지 않습니다.

## 9. 변환 전 확인 정책

### 최초 1회 확인
처음 변환을 실행할 때 한 번만 확인 창이 나타납니다.
**앞으로 묻지 않기**를 선택하면 이후에는 즉시 변환하고 결과만 보여 줍니다. (설정에서 되돌릴 수 있음)

### 위험 조건일 때 추가 확인
“묻지 않기”를 켰더라도 아래 중 하나라도 해당하면 변환 직전에 다시 확인합니다.

- 검사 대상이 100개 이상
- 실제 이름 변경 대상이 50개 이상
- 이름 충돌이 1개 이상
- iCloud Drive, Dropbox, OneDrive, Google Drive 등 동기화 경로
- 외장 디스크 또는 네트워크 볼륨
- Git 저장소 내부로 추정되는 경로
- package(.app 등) 내부 재귀 변환 옵션이 켜져 있음

확인 창에는 바뀔 항목 수, 유지될 항목 수, 건너뛸 항목 수, 위험 요약과 **취소 / 계속 변환** 버튼이 표시됩니다.

## 10. Finder 서비스(빠른 동작) 활성화 방법

quickJaso는 macOS **서비스(NSServices)** 로 Finder에 통합됩니다. 별도 Automator 워크플로가 필요 없습니다.

1. `build/quickJaso.app`을 **`/Applications`** (또는 `~/Applications`)로 옮깁니다.
2. 앱을 한 번 실행합니다. (Launch Services가 서비스를 등록합니다.)
3. 서비스가 보이지 않으면 다음 중 하나를 수행합니다.
   - 로그아웃 후 다시 로그인
   - 또는 터미널에서 서비스 캐시 갱신:

```bash
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f /Applications/quickJaso.app
```

4. **시스템 설정 → 키보드 → 키보드 단축키… → 서비스 → 파일 및 폴더**에서
   `Windows 호환 검사`, `Windows 호환 파일명으로 변환`이 체크되어 있는지 확인합니다. 여기서 단축키도 지정할 수 있습니다.
5. Finder에서 파일을 우클릭하면 **서비스** 하위 메뉴(또는 메뉴 하단)에 두 항목이 나타납니다.
   Finder는 서비스 항목을 제목 문자열 순으로 정렬하므로 `Windows 호환 검사`가 위, `Windows 호환 파일명으로 변환`이 아래에 표시됩니다.

**제한**: macOS의 “빠른 동작(Quick Actions)” 섹션은 Automator 워크플로/Action Extension 전용이라, 앱 서비스는 **서비스** 섹션에 표시됩니다. 서비스 항목이 적으면 컨텍스트 메뉴 하단에 직접 노출됩니다.

## 11. 권한, Sandbox, security-scoped URL

- 앱을 서비스 또는 URL로 실행하면 메인 창은 뜨지 않고 **결과 패널만** 표시됩니다. 메인 창은 Dock 아이콘 클릭이나 앱을 직접 실행했을 때 나타납니다.
- 기본 빌드는 **App Sandbox를 켜지 않습니다.** 서비스로 전달된 파일 URL에 대한 sandbox 접근 보장이 macOS 버전에 따라 불확실하기 때문입니다. 대신 Finder가 서비스 pasteboard(`public.file-url`)로 넘겨준 URL만 사용하며, 임의 경로 문자열이나 shell 명령은 사용하지 않습니다.
- 코드 전반은 `startAccessingSecurityScopedResource()` / `stopAccessingSecurityScopedResource()` 패턴을 사용하므로, `Resources/quickJaso.entitlements`를 적용해 sandbox를 켜도 드래그 앤 드롭·열기 패널 경로에서는 동작합니다.
- 전체 디스크 접근 권한이 없으면 외장 디스크, 네트워크 볼륨, `~/Desktop`·`~/Documents` 등 보호 폴더에 접근할 때 macOS가 **폴더 접근 권한** 대화상자를 띄울 수 있습니다. 거부하면 해당 항목은 `변환 불가 — 접근 오류`로 보고됩니다. 12장의 안내에 따라 전체 디스크 접근 권한을 주면 이 대화상자가 반복되지 않습니다.
- 읽기 전용 볼륨, 잠긴 파일, 권한 없는 폴더는 변경하지 않고 오류로 보고합니다.
- Git 저장소 감지는 `.git` 상위 탐색만 수행하며 Git 명령을 실행하거나 Git 상태를 바꾸지 않습니다.

## 12. 전체 디스크 접근 권한 안내

이 앱은 macOS 로컬 알림(Notification)을 사용하지 않습니다. 모든 결과는 앱 자체의 결과 패널과 상세 창으로 표시됩니다.

앱을 **처음 실행하면** `권한 설정 안내` 창이 나타나 macOS **전체 디스크 접근 권한**(Full Disk Access)을 설정하도록 안내합니다.

- 데스크탑, 문서, 다운로드, 외장 디스크, iCloud Drive 등 보호된 위치의 항목을 매번 묻지 않고 처리하려면 이 권한이 필요합니다.
- 권한을 주지 않아도 앱은 동작하지만, 접근할 수 없는 항목은 `변환 불가 — 접근 오류`로 표시됩니다.
- 앱은 권한을 스스로 바꾸지 않습니다. `시스템 설정 열기` 버튼은 **시스템 설정 → 개인정보 보호 및 보안 → 전체 디스크 접근 권한** 화면을 열어 줄 뿐이며, 목록에서 quickJaso를 켜는 것은 사용자가 직접 합니다. 목록에 없으면 `+` 버튼으로 `/Applications/quickJaso.app`을 추가하세요.
- 권한 변경 후에는 quickJaso를 종료했다가 다시 실행해야 적용됩니다.
- `앞으로 표시하지 않기`를 선택하면 안내 창이 더 이상 자동으로 뜨지 않습니다. 언제든 **도움말 → 전체 디스크 접근 권한 설정…** 메뉴나 설정(`⌘,`)에서 다시 열 수 있습니다.
- 안내 창의 `현재 상태`는 보호된 폴더 목록을 읽어 보는 방식으로 추정한 값이라 정확하지 않을 수 있습니다.

## 13. 빌드 방법

요구 사항: macOS 13 이상, Xcode 15 이상(권장: Xcode 26), 명령줄 도구.

```bash
# 라이브러리·앱 컴파일
swift build
```

```bash
# 실행 가능한 .app 번들 생성 (build/quickJaso.app)
./scripts/build-app.sh
```

```bash
# 배포용 DMG 생성 (dist/quickJaso-<버전>.dmg, sha256, Homebrew cask 파일)
./scripts/build-dmg.sh
```

```bash
# 빌드 후 바로 실행
open build/quickJaso.app
```

Xcode에서 열려면 `Package.swift`를 더블클릭하면 됩니다. 단, Finder 서비스 등록에는 `Info.plist`가 포함된 `.app` 번들이 필요하므로 서비스 테스트는 `scripts/build-app.sh`로 만든 번들을 사용하세요.

## 14. 테스트 실행 방법

```bash
swift test
```

Finder 서비스 경로를 GUI 클릭 없이 검증하려면 Finder가 호출하는 것과 동일한 `NSPerformService` API를 쓰는 짧은 Swift 스크립트를 사용할 수 있습니다.

```bash
cat > /tmp/perform-service.swift <<'SWIFT'
import AppKit
let name = CommandLine.arguments[1]
let urls = CommandLine.arguments[2...].map { URL(fileURLWithPath: $0) as NSURL }
let pb = NSPasteboard(name: NSPasteboard.Name("quickjaso-test"))
pb.clearContents(); pb.writeObjects(urls)
print(NSPerformService(name, pb))
SWIFT
swiftc /tmp/perform-service.swift -o /tmp/perform-service && /tmp/perform-service "Windows 호환 검사" ~/Desktop/nfc-test
```

`Tests/QuickJasoCoreTests`에 문자열 정규화 테스트와 임시 디렉터리를 사용하는 실제 파일 시스템 테스트(NFD 생성·검사, 목적지 URL 계산, 내용 보존, 충돌 감지, 수렴 충돌, 중첩 폴더 bottom-up, symlink 미추적, package 미재귀, 읽기 전용 오류)가 포함됩니다.

## 15. 수동 테스트 체크리스트

- [ ] Finder 서비스 활성화 (시스템 설정 → 키보드 → 서비스)
- [ ] 단일 파일 검사
- [ ] 다중 파일 검사
- [ ] 폴더 재귀 검사
- [ ] 단일 파일 변환
- [ ] 다중 파일 변환
- [ ] 폴더 재귀 변환 (중첩 NFD 폴더 안의 NFD 파일)
- [ ] 이미 NFC인 항목 → “이미 Windows 호환 파일명입니다”
- [ ] NFD 한글 이름
- [ ] 결합 문자 이름 (`é`, `ñ` 등)
- [ ] 이름 충돌 (NFC 파일과 NFD 파일이 같은 폴더에 공존)
- [ ] 권한 거부 (읽기 전용 폴더)
- [ ] iCloud Drive 또는 파일 제공자 경로 (미다운로드 항목 → 확인 불가)
- [ ] 외장 디스크 (위험 확인 창 표시)
- [ ] 네트워크 볼륨 (위험 확인 창 표시)
- [ ] Git 저장소 경로 (위험 확인 창 표시)
- [ ] Light Mode
- [ ] Dark Mode
- [ ] VoiceOver로 결과 패널·상세 테이블 읽기
- [ ] 최초 실행 시 권한 설정 안내 창 → 시스템 설정 열기 → 권한 부여 후 재실행
- [ ] 전체 디스크 접근 권한 없이 보호 폴더(문서 등) 처리 → 접근 오류 표시

테스트용 NFD 파일은 터미널에서 다음처럼 만들 수 있습니다.

```bash
mkdir -p ~/Desktop/nfc-test && cd ~/Desktop/nfc-test && printf 'hello' > "$(printf '\xe1\x84\x92\xe1\x85\xa1\xe1\x86\xab\xe1\x84\x80\xe1\x85\xb3\xe1\x86\xaf.txt')"
```

## 16. 알려진 제한사항

- Finder “빠른 동작” 섹션이 아닌 **서비스** 섹션에 표시됩니다 (Action Extension 미구현).
- Finder 배지(Finder Sync Extension)는 제공하지 않습니다.
- 되돌리기(undo)는 아직 제공하지 않습니다. 작업 기록 모델(`OperationRecord`)과 UI 진입점만 있으며 TODO입니다.
- 심볼릭 링크 자체의 이름 변경은 기본 OFF이며 설정에서 켤 수 있습니다. 링크 대상은 처리하지 않습니다.
- package(.app 등) 내부는 기본적으로 처리하지 않습니다.
- 정규화 비민감 파일 시스템에서 동일 항목 여부를 판단할 수 없으면 fail-safe로 충돌 처리합니다.
- UI 언어는 한국어만 제공합니다.
- 최종 rename 단계는 Foundation 대신 BSD `renamex_np`를 사용합니다(위 8장 참고). Foundation API만으로는 APFS에서 NFD→NFC 이름 변경이 반영되지 않기 때문입니다.
- **서명·공증 없음**: Apple Developer Program($99/년) 인증서가 없어 ad-hoc 서명만 되어 있습니다. 그래서 인터넷에서 내려받은 뒤 첫 실행 시 Gatekeeper 절차(설치 절 참고)가 필요합니다. Developer ID 서명 + notarization을 적용하면 이 절차가 사라지며, `scripts/build-dmg.sh`에 인증서만 지정하면 됩니다.

## 17. 주의사항

- **중요한 파일은 변환 전 백업**을 권장합니다.
- iCloud·Dropbox·OneDrive 등 **동기화가 진행 중인 폴더**에서는 주의하세요. 동기화 클라이언트가 이름 변경을 별도 파일로 인식할 수 있습니다.
- **Git 저장소**에서는 파일명 변경이 rename(또는 delete + add)으로 인식됩니다. 변환 후 `git status`를 확인하세요.
- **외장 디스크 / NAS / 네트워크 파일 시스템**은 정규화 처리 방식이 달라 동작 차이가 있을 수 있습니다.
- **이름 충돌 항목은 자동 변경되지 않습니다.** 직접 정리한 뒤 다시 실행하세요.

## 18. 프로젝트 구조

```
quickJaso/
├── Package.swift
├── Sources/
│   ├── QuickJasoCore/       # Foundation 전용 핵심 로직 (Models, Services)
│   └── QuickJaso/           # macOS 앱 (App, ViewModels, Views, Panels, QuickAction, Services)
├── Tests/QuickJasoCoreTests/
├── Resources/               # Info.plist(NSServices), entitlements, AppIcon.icns
├── .github/workflows/ci.yml # GitHub Actions: build + test
├── scripts/                 # build-app.sh(.app 조립), build-dmg.sh(DMG·cask), make-icon.sh(아이콘)
├── docs/                    # SPEC.md, DESIGN.md
└── README.md
```

자세한 설계는 [docs/DESIGN.md](docs/DESIGN.md), 요구사항은 [docs/SPEC.md](docs/SPEC.md)를 참고하세요.

## 라이선스

MIT License. 자세한 내용은 [LICENSE](LICENSE)를 참고하세요.
