#!/bin/zsh -e

unregister_all=false
dry_run=false
for argument in "$@"; do
    if [[ "$argument" == "--all" ]]; then
        unregister_all=true
    elif [[ "$argument" == "--dry-run" ]]; then
        dry_run=true
    else
        print -u2 "사용법: $0 [--all] [--dry-run]"
        exit 2
    fi
done

lsregister_path="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
pbs_path="/System/Library/CoreServices/pbs"

registered_paths() {
    "$lsregister_path" -dump |
        grep -E '^[[:space:]]*path:[[:space:]]+/.*quickJaso\.app( \(0x[0-9a-f]+\))?[[:space:]]*$' |
        sed -E 's/^[[:space:]]*path:[[:space:]]+//; s/[[:space:]]*\(0x[0-9a-f]+\)[[:space:]]*$//' |
        grep -E '^/.*quickJaso\.app$' |
        sort -u || true
}

if [[ "$dry_run" == true ]]; then
    print "모의 실행: 등록 해제 및 pbs 명령은 실행하지 않습니다."
fi

while IFS= read -r registered_path; do
    if [[ "$unregister_all" != true && ( "$registered_path" == /Applications/quickJaso.app || "$registered_path" == "$HOME/Applications/quickJaso.app" ) ]]; then
        print -r -- "유지: $registered_path"
    else
        print -r -- "등록 해제: $registered_path"
        if [[ "$dry_run" != true ]]; then
            "$lsregister_path" -u "$registered_path" || true
        fi
    fi
done < <(registered_paths)

if [[ "$dry_run" == true ]]; then
    print "실행 예정: pbs -flush"
    print "실행 예정: pbs -update"
else
    "$pbs_path" -flush || true
    "$pbs_path" -update || true
fi

print "남아 있는 quickJaso 등록 경로:"
registered_paths
