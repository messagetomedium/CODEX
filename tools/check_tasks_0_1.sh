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
run_godot() {
    local check_name="$1"
    shift
    local check_status=0
    "$GODOT_BIN" --headless --path . "$@" > "build/checks/${check_name}.log" 2>&1 || check_status=$?
    cat "build/checks/${check_name}.log"
    if (( check_status != 0 )); then return "$check_status"; fi
    # Godot can return zero even on GDScript parse/runtime errors.
    if grep -Eq 'SCRIPT ERROR:|^ERROR:|instances leaked at exit' "build/checks/${check_name}.log"; then return 1; fi
}
run_godot import --editor --import
run_godot config --script res://tests/config_smoke_test.gd
run_godot task-1 --script res://tests/task_1_smoke_test.gd
grep -q 'Godot config smoke test OK:' build/checks/config.log
grep -q 'Task 1 integration checks: .*failed: 0' build/checks/task-1.log
run_godot web --export-release Web build/web/index.html
for artifact in index.html index.js index.wasm index.pck; do
    test -s "build/web/$artifact"
done
echo 'PASS: handoff, Godot import, config smoke, Task 1 integration, Web artifacts'
