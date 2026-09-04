#!/bin/zsh -e

cd "${0:A:h}/.."

export CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$CLANG_MODULE_CACHE_PATH"
mkdir -p "$CLANG_MODULE_CACHE_PATH"

temp_dir="$(mktemp -d "${TMPDIR:-/tmp}/quickjaso-icon.XXXXXX")"
trap 'rm -rf "$temp_dir"' EXIT

source_png="$temp_dir/AppIcon-1024.png"
iconset_path="$temp_dir/AppIcon.iconset"
mkdir -p "$iconset_path" Resources

swift scripts/make-icon.swift "$source_png"

make_size() {
    local pixels="$1"
    local filename="$2"
    sips -z "$pixels" "$pixels" "$source_png" --out "$iconset_path/$filename" >/dev/null
}

make_size 16 icon_16x16.png
make_size 32 icon_16x16@2x.png
make_size 32 icon_32x32.png
make_size 64 icon_32x32@2x.png
make_size 128 icon_128x128.png
make_size 256 icon_128x128@2x.png
make_size 256 icon_256x256.png
make_size 512 icon_256x256@2x.png
make_size 512 icon_512x512.png
make_size 1024 icon_512x512@2x.png

if ! iconutil -c icns "$iconset_path" -o Resources/AppIcon.icns; then
    print -u2 "경고: iconutil이 iconset을 변환하지 못해 Swift ICNS 폴백을 사용합니다."
    swift scripts/make-icon.swift --assemble-icns "$iconset_path" Resources/AppIcon.icns
fi
print "완료: Resources/AppIcon.icns"
