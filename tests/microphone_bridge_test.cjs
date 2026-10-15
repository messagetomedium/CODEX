const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const source = fs.readFileSync('web/microphone_bridge.js', 'utf8');
const settle = () => new Promise(resolve => setImmediate(resolve));

function environment(options = {}) {
  const requests = [], contexts = [], connections = [];
  const documentEvents = new Map(), windowEvents = new Map();
  let amplitude = 0.25;
  class Context {
    constructor() { this.state = 'suspended'; this.sampleRate = 48000; this.destination = {}; this.closes = 0; contexts.push(this); }
    resume() { this.state = 'running'; return Promise.resolve(); }
    close() { this.state = 'closed'; this.closes++; return Promise.resolve(); }
    createMediaStreamSource() { return { connect: node => connections.push(node), disconnect() {} }; }
    createAnalyser() { this.analyser = { fftSize: 2048, smoothingTimeConstant: 0, getFloatTimeDomainData: buffer => buffer.fill(amplitude), disconnect() {} }; return this.analyser; }
  }
  const window = {
    isSecureContext: options.secure !== false,
    AudioContext: options.supported === false ? undefined : Context,
    addEventListener: (name, fn) => windowEvents.set(name, fn),
    removeEventListener: name => windowEvents.delete(name),
  };
  const navigator = { mediaDevices: { getUserMedia(constraints) {
    return new Promise((resolve, reject) => requests.push({ constraints, resolve, reject }));
  } } };
  const document = { addEventListener: (name, fn) => documentEvents.set(name, fn), removeEventListener: name => documentEvents.delete(name) };
  const sandbox = vm.createContext({ window, navigator, document, performance: { now: () => 123.5 }, Float32Array, fetch() { assert.fail('No network allowed'); }, MediaRecorder() { assert.fail('No recording allowed'); } });
  const evaluate = () => vm.runInContext(source, sandbox);
  evaluate();
  return { window, requests, contexts, connections, documentEvents, windowEvents, evaluate, setAmplitude: value => { amplitude = value; } };
}
function stream() {
  const listeners = new Map();
  const track = { readyState: 'live', stopped: 0, stop() { this.stopped++; this.readyState = 'ended'; }, addEventListener: (name, fn) => listeners.set(name, fn), removeEventListener: name => listeners.delete(name), end() { listeners.get('ended')?.(); } };
  return { track, getTracks: () => [track], getAudioTracks: () => [track] };
}

test('loading never requests microphone or constructs an AudioContext', () => {
  const e = environment();
  assert.equal(e.requests.length, 0);
  assert.equal(e.contexts.length, 0);
  assert.equal(e.window.MatryoshkaMic.status, 'idle');
});

test('Start requests audio only, measures RMS/peak, and never connects to speakers', async () => {
  const e = environment(), api = e.window.MatryoshkaMic, s = stream();
  api.start(35);
  assert.equal(api.status, 'pending');
  assert.equal(e.requests[0].constraints.video, false);
  assert.deepEqual(JSON.parse(JSON.stringify(e.requests[0].constraints.audio)), { echoCancellation: true, noiseSuppression: true, autoGainControl: false });
  e.requests[0].resolve(s); await settle();
  assert.equal(api.status, 'active');
  const frame = api.sample();
  assert.equal(frame.rms, 0.25); assert.equal(frame.peak, 0.25); assert.equal(frame.timestamp, 123.5);
  assert.deepEqual(e.connections, [e.contexts[0].analyser]);
  assert.ok(!e.connections.includes(e.contexts[0].destination));
  e.setAmplitude(NaN); assert.equal(api.sample().rms, 0);
  api.stop();
  assert.equal(s.track.stopped, 1); assert.equal(e.contexts[0].closes, 1);
  assert.equal(api.sample().rms, 0); assert.equal(api.status, 'idle');
});

test('reset before permission grant stops the late stream and cannot reactivate', async () => {
  const e = environment(), api = e.window.MatryoshkaMic, s = stream();
  api.start(35); api.stop(); e.requests[0].resolve(s); await settle();
  assert.equal(s.track.stopped, 1); assert.equal(api.status, 'idle'); assert.equal(e.connections.length, 0);
});

test('a stale request cannot replace the current active stream', async () => {
  const e = environment(), api = e.window.MatryoshkaMic, old = stream(), current = stream();
  api.start(35); api.start(35);
  e.requests[1].resolve(current); await settle();
  e.requests[0].resolve(old); await settle();
  assert.equal(old.track.stopped, 1); assert.equal(current.track.stopped, 0); assert.equal(api.status, 'active');
  api.dispose(); assert.equal(current.track.stopped, 1);
});

for (const [name, status] of [['NotAllowedError', 'denied'], ['NotFoundError', 'not-found'], ['NotReadableError', 'busy'], ['UnknownError', 'error']]) {
  test(`${name} is recoverable with a fresh retry`, async () => {
    const e = environment(), api = e.window.MatryoshkaMic;
    api.start(35); e.requests[0].reject({ name }); await settle();
    assert.equal(api.status, status); assert.equal(e.contexts[0].closes, 1);
    api.start(35); const s = stream(); e.requests[1].resolve(s); await settle();
    assert.equal(api.status, 'active'); assert.equal(api.errorCode, ''); api.dispose();
  });
}

test('disconnected device releases the stream and reports a retryable error', async () => {
  const e = environment(), api = e.window.MatryoshkaMic, s = stream();
  api.start(35); e.requests[0].resolve(s); await settle(); s.track.end();
  assert.equal(api.status, 'not-found'); assert.equal(api.errorCode, 'disconnected');
  assert.equal(s.track.stopped, 1); assert.equal(e.contexts[0].state, 'closed');
});

test('page exit and dispose release resources and event handlers', async () => {
  const e = environment(), api = e.window.MatryoshkaMic, s = stream();
  api.start(35); e.requests[0].resolve(s); await settle(); e.windowEvents.get('pagehide')();
  assert.equal(s.track.stopped, 1); assert.equal(api.status, 'idle');
  api.dispose(); assert.equal(api.disposed, true); assert.equal(e.documentEvents.size, 0); assert.equal(e.windowEvents.size, 0);
  assert.equal(e.window.MatryoshkaMic, undefined);
  e.evaluate(); assert.equal(e.window.MatryoshkaMic.status, 'idle');
});

test('insecure or unsupported browsers show an error without requesting audio', () => {
  for (const [options, code] of [[{ secure: false }, 'insecure'], [{ supported: false }, 'unsupported']]) {
    const e = environment(options); e.window.MatryoshkaMic.start(35);
    assert.equal(e.window.MatryoshkaMic.status, 'error'); assert.equal(e.window.MatryoshkaMic.errorCode, code); assert.equal(e.requests.length, 0);
  }
});
