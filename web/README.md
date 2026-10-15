# Browser microphone module — future Task 2

The actual browser microphone bridge does not exist in bootstrap v1.0.
Codex must create `web/microphone_bridge.js` during Task 2 and wire it to
`JavaScriptBridge` from GDScript. The Web export preset already includes
`web/*.js` in the exported PCK. See TECH_ARCHITECTURE_v1.0.md.

Never route the microphone MediaStream to AudioContext.destination.
No audio playback of any kind is part of this prototype.
