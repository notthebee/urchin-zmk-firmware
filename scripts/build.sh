#!/usr/bin/env bash
# Build every entry of build.yaml, the way zmk's reusable workflow does.
#
#   nix develop --command scripts/build.sh
#
# The west workspace is the repo root, so the trees west fetches (zmk/, zephyr/,
# modules/, urchin-zmk-module/) live next to config/. `build/` is gitignored.
set -euo pipefail

ws=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
ws=${WS:-$ws}
artifacts=${ARTIFACTS:-$ws/build/artifacts}
cd "$ws"

if [ ! -d .west ]; then
    west init -l "$ws/config"
fi
if [ "${WEST_UPDATE:-1}" = 1 ]; then
    west update --fetch-opt=--filter=tree:0
    west zephyr-export
fi

mkdir -p "$artifacts"

failed=
while IFS=$'\t' read -r board shield snippet cmake_args; do
    name=${shield%% *}
    name=${name:-$board}
    dir=$ws/build/$name

    echo "==> $name"
    args=(-s zmk/app -d "$dir" -b "$board")
    [ -n "$snippet" ] && args+=(-S "$snippet")
    args+=(-- "-DZMK_CONFIG=$ws/config")
    [ -n "$shield" ] && args+=("-DSHIELD=$shield")
    [ -n "$cmake_args" ] && args+=($cmake_args)

    if west build "${args[@]}"; then
        for ext in uf2 bin; do
            if [ -f "$dir/zephyr/zmk.$ext" ]; then
                cp "$dir/zephyr/zmk.$ext" "$artifacts/$name.$ext"
                break
            fi
        done
    else
        failed="$failed $name"
    fi
done < <(yq -o=tsv '.include[] | [.board, (.shield // ""), (.snippet // ""), (.["cmake-args"] // "")]' "$ws/build.yaml")

if [ -n "$failed" ]; then
    echo "failed:$failed" >&2
    exit 1
fi
echo "artifacts: $artifacts"
