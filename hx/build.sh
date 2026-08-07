#!/usr/bin/env bash
# Compile every sample project under hx/src on the given targets and print a pass/fail table.
#
#   ./build.sh                          # every target below
#   ./build.sh html5                    # one target
#   ./build.sh neko DrawingShapes       # one target, named projects
#
# Targets map onto Lime render contexts, which is what selects the Flight backend:
#
#   neko          OPENGL   (CAIRO with hardware="false")
#   html5         WEBGL
#   html5-canvas  CANVAS   (lime build html5 -Dcanvas)
#   html5-dom     DOM      (lime build html5 -Ddom)
#
# The three html5 rows are the same three backends ts/ publishes per sample. only
#
# Requires: haxe, neko, and `haxelib run lime` (lime 8.x), with `haxelib dev flight <flight-hx>`
# already pointing at a flight-hx checkout (project.xml pulls it in as `<haxelib name="flight" />`).
set -uo pipefail

cd "$(dirname "$0")"

case "${1:-}" in
  neko | html5 | html5-canvas | html5-dom)
    targets=("$1")
    shift
    ;;
  *) targets=(neko html5 html5-canvas html5-dom) ;;
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
for t in "${targets[@]}"; do printf '%-14s' "$t"; done
printf '\n'

for p in "${projects[@]}"; do
  printf '%-26s' "$p"
  for t in "${targets[@]}"; do
    if [ ! -f "$p/project.xml" ]; then
      printf '%-14s' 'no-proj'
      fail=1
      continue
    fi
    # Scaffolded but not ported yet: report distinctly rather than as a compile failure.
    if [ ! -f "$p/src/Main.hx" ]; then
      printf '%-14s' '-'
      continue
    fi
    # html5-<backend> is `lime build html5 -D<backend>`; Lime reads that define to pick the context.
    platform="${t%%-*}"
    define=()
    [ "$t" != "$platform" ] && define=(-D "${t#*-}")
    log="$p/bin/build-$t.log"
    mkdir -p "$p/bin"
    if (cd "$p" && haxelib run lime build "$platform" "${define[@]}") >"$log" 2>&1; then
      printf '%-14s' 'ok'
    else
      printf '%-14s' 'FAIL'
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
