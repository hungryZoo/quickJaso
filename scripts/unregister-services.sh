#!/bin/zsh -e

unregister_all=false
for argument in "$@"; do
    if [[ "$argument" == "--all" ]]; then
        unregister_all=true
    else
        print -u2 "사용법: $0 [--all]"
        exit 2
    fi
done

lsregister_path="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
pbs_path="/System/Library/CoreServices/pbs"

registered_paths() {
    "$lsregister_path" -dump |
        grep -E '^[[:space:]]*path:[[:space:]]+.*quickJaso\.app' |
        sed -E 's/^[[:space:]]*path:[[:space:]]+//' || true
}

while IFS= read -r registered_path; do
    if [[ "$unregister_all" == true || "$registered_path" != /Applications/quickJaso.app || ! -e "$registered_path" ]]; then
        print -r -- "등록 해제: $registered_path"
        "$lsregister_path" -u "$registered_path" || true
    fi
done < <(registered_paths)

"$pbs_path" -flush || true
"$pbs_path" -update || true

print "남아 있는 quickJaso 등록 경로:"
registered_paths
