#!/bin/zsh -e

cd "${0:A:h}/.."

export CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$CLANG_MODULE_CACHE_PATH"
mkdir -p "$CLANG_MODULE_CACHE_PATH"

use_sandbox=false
for argument in "$@"; do
    if [[ "$argument" == "--sandbox" ]]; then
        use_sandbox=true
    else
        print -u2 "알 수 없는 옵션: $argument"
        exit 2
    fi
done

swift build --disable-sandbox -c release --product QuickJaso

app_path="build/quickJaso.app"
contents_path="$app_path/Contents"
macos_path="$contents_path/MacOS"
resources_path="$contents_path/Resources"

if [[ -d "$app_path" ]]; then
    rm -rf "$app_path"
fi
mkdir -p "$macos_path" "$resources_path"
cp ".build/release/QuickJaso" "$macos_path/QuickJaso"
cp "Resources/Info.plist" "$contents_path/Info.plist"
print -n "APPL????" > "$contents_path/PkgInfo"

cp "Resources/AppIcon.icns" "$resources_path/AppIcon.icns"

if [[ "$use_sandbox" == true ]]; then
    codesign --force --sign - --deep --entitlements "Resources/quickJaso.entitlements" "$app_path"
else
    codesign --force --sign - --deep "$app_path"
fi

lsregister_path="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
if ! "$lsregister_path" -f "$app_path"; then
    print -u2 "Launch Services 등록에 실패했습니다. 앱을 한 번 직접 열어 등록할 수 있습니다."
fi

print "완료: $app_path"
print "실행: open $app_path"
print "Finder 서비스가 보이지 않으면 시스템 설정 > 키보드 > 키보드 단축키 > 서비스에서 활성화하세요."
