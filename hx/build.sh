#!/usr/bin/env bash
# Compile every sample project under hx/src on the given targets and print a pass/fail table.
#
#   ./build.sh                  # neko and html5
#   ./build.sh html5            # one target
#   ./build.sh neko DrawingShapes AddingText   # one target, named projects only
#
# Requires: haxe, neko, and `haxelib run lime` (lime 8.x), with `haxelib dev flight <flight-hx>`
# already pointing at a flight-hx checkout (project.xml pulls it in as `<haxelib name="flight" />`).
set -uo pipefail

cd "$(dirname "$0")"

case "${1:-}" in
  neko | html5)
    targets=("$1")
    shift
    ;;
  *) targets=(neko html5) ;;
esac

if [ "$#" -gt 0 ]; then
  projects=("$@")
else
  mapfile -t projects < <(for d in */; do [ -f "$d/project.xml" ] && echo "${d%/}"; done | sort)
fi

if [ "${#projects[@]}" -eq 0 ]; then
  echo "no projects under hx/"
  exit 0
fi

fail=0
printf '%-26s' 'project'
for t in "${targets[@]}"; do printf '%-10s' "$t"; done
printf '\n'

for p in "${projects[@]}"; do
  printf '%-26s' "$p"
  for t in "${targets[@]}"; do
    if [ ! -f "$p/project.xml" ]; then
      printf '%-10s' 'no-proj'
      fail=1
      continue
    fi
    # Scaffolded but not ported yet: report distinctly rather than as a compile failure.
    if [ ! -f "$p/src/Main.hx" ]; then
      printf '%-10s' '-'
      continue
    fi
    log="$p/bin/build-$t.log"
    mkdir -p "$p/bin"
    if (cd "$p" && haxelib run lime build "$t") >"$log" 2>&1; then
      printf '%-10s' 'ok'
    else
      printf '%-10s' 'FAIL'
      fail=1
    fi
  done
  printf '\n'
done

if [ "$fail" -ne 0 ]; then
  echo
  echo "failures above; per-project logs at hx/<project>/bin/build-<target>.log"
fi
exit "$fail"
