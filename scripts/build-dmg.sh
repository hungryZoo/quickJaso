#!/bin/zsh -e

cd "${0:A:h}/.."

if (( $# > 1 )); then
    print -u2 "사용법: $0 [version]"
    exit 2
fi

plist_path="Resources/Info.plist"
if (( $# == 1 )); then
    version="$1"
    if [[ ! "$version" =~ '^[0-9]+([.][0-9]+)*([+-][0-9A-Za-z.-]+)?$' ]]; then
        print -u2 "올바르지 않은 버전: $version"
        exit 2
    fi
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $version" "$plist_path"
else
    version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$plist_path")"
fi

dist_path="dist"
staging_path="$dist_path/dmg-staging"
legacy_mount_path="$dist_path/dmg-mount"
read_write_dmg="$dist_path/quickJaso-layout-rw.dmg"
hybrid_dmg="$dist_path/quickJaso-layout-hybrid.dmg"
dmg_path="$dist_path/quickJaso-$version.dmg"
checksum_path="$dmg_path.sha256"
cask_path="$dist_path/quickjaso.rb"

attached=false
mount_path=""
detach_target=""
cleanup() {
    local exit_status=$?

    if [[ "$attached" == true && -n "$detach_target" ]]; then
        hdiutil detach "$detach_target" -force >/dev/null 2>&1 || true
    fi

    rm -rf -- \
        "$staging_path" \
        "$legacy_mount_path" \
        "$dist_path"/hdiutil-probe.*(N) \
        "$dist_path"/mount-probe.*(N)
    rm -f -- "$read_write_dmg" "$hybrid_dmg"

    return "$exit_status"
}
trap cleanup EXIT

./scripts/build-app.sh

rm -rf "$staging_path" "$legacy_mount_path" \
    "$dist_path"/hdiutil-probe.*(N) \
    "$dist_path"/mount-probe.*(N)
rm -f "$read_write_dmg" "$hybrid_dmg" "$dmg_path" "$checksum_path"
mkdir -p "$staging_path"
ditto "build/quickJaso.app" "$staging_path/quickJaso.app"
ln -s /Applications "$staging_path/Applications"
chmod -Rf go-w "$staging_path"

if hdiutil create \
    -format UDRW \
    -fs HFS+ \
    -volname "quickJaso" \
    -srcfolder "$staging_path" \
    -ov \
    "$read_write_dmg" >/dev/null
then
    attach_output=""
    if attach_output="$(hdiutil attach "$read_write_dmg" -readwrite -noverify -noautoopen)"; then
        mount_path="$(print -r -- "$attach_output" | awk -F '\t' '$NF ~ /^\/Volumes\// { print $NF; exit }')"
        detach_target="$(print -r -- "$attach_output" | awk '$1 ~ /^\/dev\// { print $1; exit }')"
        attached=true
    fi

    if [[ -n "$mount_path" ]]; then
        detach_target="$mount_path"
        if ! osascript <<'APPLESCRIPT'
tell application "Finder"
    tell disk "quickJaso"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {200, 120, 760, 480}
        set theViewOptions to the icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 128
        set text size of theViewOptions to 14
        set position of item "quickJaso.app" of container window to {150, 180}
        set position of item "Applications" of container window to {410, 180}
        close
        open
        update without registering applications
        delay 1
        close
    end tell
end tell
APPLESCRIPT
        then
            print -u2 "경고: Finder 창 레이아웃을 설정하지 못했습니다. 기본 레이아웃으로 계속합니다."
        fi

        sync
        hdiutil detach "$mount_path" >/dev/null
        attached=false
        mount_path=""
        detach_target=""
    else
        print -u2 "경고: 레이아웃용 DMG를 마운트하지 못했습니다. 기본 레이아웃으로 계속합니다."
        if [[ "$attached" == true && -n "$detach_target" ]]; then
            hdiutil detach "$detach_target" >/dev/null
            attached=false
            detach_target=""
        fi
    fi

    hdiutil convert "$read_write_dmg" \
        -format UDZO \
        -imagekey zlib-level=9 \
        -ov \
        -o "$dmg_path" >/dev/null
    rm -f "$read_write_dmg"
else
    print -u2 "경고: 쓰기 가능한 DMG를 만들지 못해 Finder 레이아웃 없이 하이브리드 이미지 폴백을 사용합니다."
    hdiutil makehybrid \
        -hfs \
        -hfs-volume-name "quickJaso" \
        -o "$hybrid_dmg" \
        "$staging_path" >/dev/null
    hdiutil convert "$hybrid_dmg" \
        -format UDZO \
        -imagekey zlib-level=9 \
        -ov \
        -o "$dmg_path" >/dev/null
    rm -f "$hybrid_dmg"
fi

rm -rf "$staging_path"

sha256="$(shasum -a 256 "$dmg_path" | awk '{print $1}')"
print "$sha256  $(basename "$dmg_path")" > "$checksum_path"

cat > "$cask_path" <<CASK
cask "quickjaso" do
  version "$version"
  sha256 "$sha256"

  url "https://github.com/hungryZoo/quickJaso/releases/download/v#{version}/quickJaso-#{version}.dmg"
  name "quickJaso"
  desc "Finder service that inspects and converts file names to Unicode NFC for Windows compatibility"
  homepage "https://github.com/hungryZoo/quickJaso"

  depends_on macos: :ventura

  app "quickJaso.app"

  caveats <<~EOS
    quickJaso is ad-hoc signed and not notarized, so macOS Gatekeeper will
    block the first launch. After installing, either run:
      xattr -dr com.apple.quarantine "#{appdir}/quickJaso.app"
    or open System Settings > Privacy & Security and click "Open Anyway".
  EOS

  zap trash: [
    "~/Library/Preferences/com.heonzoo.quickJaso.plist",
  ]
end
CASK

print "DMG: $PWD/$dmg_path"
print "SHA-256: $sha256"
print "Cask: $PWD/$cask_path"
