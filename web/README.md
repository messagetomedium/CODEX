# Browser microphone — Task 2

`microphone_bridge.js` is read from the Godot PCK with FileAccess and evaluated
by `BrowserVoiceInput` through JavaScriptBridge. It is not an HTTP module.

Start/Retry is the only permission entry point. The bridge owns one session,
tracks a generation token, stops late-granted streams, and disconnects/closes
its resources on reset, device loss, page exit and dispose. The microphone
source connects only to AnalyserNode; its output remains disconnected.
No recording, playback, voice uploads or third-party libraries are used.

`sample()` returns status, errorCode, rms, peak and a monotonic timestamp.
GDScript handles normalization, automatic background estimate, sustained quiet
input, sharp attacks, release/cooldown and the source-independent VoiceFrame.

Normal play always uses the browser microphone. `?debug=1` explicitly selects
keyboard debug without requesting audio. Native debug requires `--voice-debug`.
A microphone failure never enables keyboard input automatically.

Run `node --test tests/microphone_bridge_test.cjs` and
`bash tools/check_tasks_0_1.sh`. For optional Chromium integration, serve
`build/web` locally on port 8765, then run `python3 tests/web_smoke_test.py`.
That test uses a generated synthetic WAV outside the checkout and fake browser
capture, not a physical microphone. Never claim physical-device testing from it.

The owner still needs to verify HTTPS permission, real speech/meter response,
denial/retry, no speaker monitoring and cleanup after Reset on the published site.
Task 3 consumes the same VoiceFrame in `scripts/goal/logic/goal_simulation.gd`.
Projection, ball motion and swept collisions are deterministic RefCounted classes;
random defender scheduling is separate, and `goal_world.gd` only draws their state.
Intro/permission/error overlays and resolved plays stop both simulation and spawning.
Microphone recovery preserves the same ball, including a flight paused in midair.
Task 4 adds RoundProgress (first-motion charging, three goals/six resolved balls),
safe compact feedback and automatic next balls. Round finals use the same central
panel dimensions as the intro. Retry reuses working audio without an intro;
a disconnected device reconnects from the retry click. Frame contacts and raised-
hands catches are distinct from ordinary saves. Microphone timing stays unchanged.

`python3 tests/web_smoke_test.py` also plays a full six-failure debug round,
checks the large central final, disabled Next and Retry. `python3 tests/visual_review.py`
locally overrides only the served HTML response to launch an explicit GDScript
review fixture for catch, goal and winning-final drawing. It uses the real Godot
mechanics/UI with controlled inputs and keeper placement, not physical speech.
Normal exported HTML/Pages never selects the review fixture.
