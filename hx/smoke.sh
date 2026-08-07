#!/usr/bin/env bash
# Run each built neko app briefly and fail on an uncaught exception.
#
# Compiling proves nothing about assets: a project whose <assets> tag is missing embed="true" builds
# clean and then dies at startup with
#   [lime.utils.Assets] ERROR: There is no asset library named "default", or it is not yet preloaded
# because the non-embedded default library is never preloaded on these targets. Same for a wrong
# asset id, which only shows up as the 'Missing asset: <id>' throw from LimeAssets. This catches both.
#
#   ./smoke.sh                 # every built project
#   ./smoke.sh DrawingShapes   # named projects
#
# Needs a build first (./build.sh neko) and xvfb for the headless window.
set -uo pipefail

cd "$(dirname "$0")"

SECONDS_PER_APP="${SMOKE_SECONDS:-6}"

if [ "$#" -gt 0 ]; then
  projects=("$@")
else
  mapfile -t projects < <(for d in */; do [ -f "$d/project.xml" ] && echo "${d%/}"; done | sort)
fi

if ! command -v xvfb-run >/dev/null 2>&1; then
  echo "xvfb-run not found; install xvfb to run the headless smoke test" >&2
  exit 2
fi

fail=0
printf '%-26s %s\n' 'project' 'neko run'
for p in "${projects[@]}"; do
  bin="$p/bin/neko/bin/$p"
  [ -x "$bin" ] || continue
  printf '%-26s ' "$p"
  out=$( (cd "$p" && timeout "$SECONDS_PER_APP" xvfb-run -a "./bin/neko/bin/$p") 2>&1 )
  # ALSA has no sound card in a headless container; that noise is expected and not a failure.
  if grep -qiE 'uncaught exception|Missing asset:|no asset library' <<<"$out"; then
    printf 'FAIL\n'
    grep -iE 'uncaught exception|Missing asset:|no asset library' <<<"$out" | head -2 | sed 's/^/    /'
    fail=1
  else
    printf 'ok\n'
  fi
done

exit "$fail"
