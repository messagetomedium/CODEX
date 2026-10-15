#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT_BIN="${GODOT_BIN:-godot}"
if ! "$GODOT_BIN" --headless --version | grep -q '^4\.5\.2\.stable\.'; then
    echo 'Godot 4.5.2 standard is required.' >&2
    exit 1
fi
python3 tools/validate_handoff.py
mkdir -p build/checks build/web
touch build/.gdignore
report_failure() {
    python3 - "$1" "build/checks/$1.log" <<'PY_REPORT'
import re, sys
from pathlib import Path
name = sys.argv[1]
log = re.sub(r"\x1b\[[0-9;]*m", "", Path(sys.argv[2]).read_text())
excerpt = "\n".join(log.splitlines()[-50:])[-6000:]
for old, new in [("%", "%25"), ("\r", "%0D"), ("\n", "%0A")]:
    excerpt = excerpt.replace(old, new)
print(f"::error title=Godot {name} check failed::{excerpt}")
PY_REPORT
}
run_godot() {
    local check_name="$1"
    shift
    local check_status=0
    "$GODOT_BIN" --headless --path . "$@" > "build/checks/${check_name}.log" 2>&1 || check_status=$?
    cat "build/checks/${check_name}.log"
    if (( check_status != 0 )); then report_failure "$check_name"; return "$check_status"; fi
    # Godot can return zero even on GDScript parse/runtime errors.
    if grep -Eq 'SCRIPT ERROR:|^ERROR:|instances leaked at exit' "build/checks/${check_name}.log"; then report_failure "$check_name"; return 1; fi
}
run_godot import --editor --import
run_godot config --script res://tests/config_smoke_test.gd
run_godot task-1 --script res://tests/task_1_smoke_test.gd
grep -q 'Godot config smoke test OK:' build/checks/config.log
grep -q 'Task 1 integration checks: .*failed: 0' build/checks/task-1.log
run_godot voice --script res://tests/voice_detector_test.gd
run_godot voice-debug --script res://tests/voice_detector_test.gd -- --voice-debug
run_godot task-2 --script res://tests/task_2_smoke_test.gd
grep -q 'Voice detector checks: .*failed: 0' build/checks/voice.log
grep -q 'Voice detector checks: .*failed: 0' build/checks/voice-debug.log
grep -q 'Task 2 integration checks: .*failed: 0' build/checks/task-2.log
run_godot mechanics --script res://tests/goal_simulation_test.gd
run_godot depth --script res://tests/depth_collision_test.gd
run_godot task-3 --script res://tests/task_3_smoke_test.gd
grep -q 'Goal simulation checks: .*failed: 0' build/checks/mechanics.log
grep -q 'Depth collision checks: .*failed: 0' build/checks/depth.log
grep -q 'Task 3 integration checks: .*failed: 0' build/checks/task-3.log
run_godot round --script res://tests/round_progress_test.gd
run_godot task-4 --script res://tests/task_4_smoke_test.gd
grep -q 'Round/frame checks: .*failed: 0' build/checks/round.log
grep -q 'Task 4 integration checks: .*failed: 0' build/checks/task-4.log
run_godot campaign --script res://tests/campaign_test.gd
run_godot campaign-scene --script res://tests/campaign_scene_test.gd
grep -q 'Campaign mechanics checks: .*failed: 0' build/checks/campaign.log
grep -q 'Campaign scene checks: .*failed: 0' build/checks/campaign-scene.log
run_godot stands --script res://tests/stands_match_test.gd
run_godot stands-scene --script res://tests/stands_scene_test.gd
grep -q 'Stands mechanics checks: .*failed: 0' build/checks/stands.log
grep -q 'Stands scene checks: .*failed: 0' build/checks/stands-scene.log
run_godot commentator --script res://tests/commentator_session_test.gd
run_godot commentator-scene --script res://tests/commentator_scene_test.gd
grep -q 'Commentator mechanics checks: .*failed: 0' build/checks/commentator.log
grep -q 'Commentator scene checks: .*failed: 0' build/checks/commentator-scene.log
node --test tests/microphone_bridge_test.cjs
run_godot web --export-release Web build/web/index.html
for artifact in index.html index.js index.wasm index.pck; do
    test -s "build/web/$artifact"
done
cp assets/commentator/fonts/LICENSE.txt build/web/LICENSE-DejaVu.txt
echo 'PASS: handoff, Godot import, config smoke, Task 1/2/3/4 integration, three-round campaign, depth-aware soft collisions, voice detector, three Stands levels, three Commentator levels, JS bridge, Web artifacts'
