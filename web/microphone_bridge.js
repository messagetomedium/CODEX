/* Browser-only microphone analysis. No recording, output connection or network. */
(() => {
  "use strict";
  if (window.MatryoshkaMic && !window.MatryoshkaMic.disposed) return;

  let generation = 0;
  let resource = null;
  let disposed = false;
  let status = "idle";
  let errorCode = "";
  let rms = 0;
  let peak = 0;
  let timestamp = 0;

  function stopTracks(stream) {
    if (stream) stream.getTracks().forEach(track => track.stop());
  }

  function release(current) {
    if (!current) return;
    current.endedListeners.forEach(([track, listener]) => track.removeEventListener("ended", listener));
    stopTracks(current.stream);
    if (current.source) current.source.disconnect();
    if (current.analyser) current.analyser.disconnect();
    if (current.context.state !== "closed") current.context.close().catch(() => {});
  }

  function stop() {
    generation += 1;
    const previous = resource;
    resource = null;
    status = "idle";
    errorCode = "";
    rms = peak = 0;
    release(previous);
  }

  function fail(token, nextStatus, code) {
    if (disposed || token !== generation) return;
    stop();
    status = nextStatus;
    errorCode = code;
  }

  function errorStatus(error) {
    const name = error && error.name;
    if (["NotAllowedError", "PermissionDeniedError", "SecurityError"].includes(name)) return "denied";
    if (["NotFoundError", "DevicesNotFoundError", "OverconstrainedError"].includes(name)) return "not-found";
    if (["NotReadableError", "TrackStartError", "AbortError"].includes(name)) return "busy";
    return "error";
  }

  function resumeOnGesture() {
    const current = resource;
    if (current && current.context.state === "suspended") {
      current.context.resume().catch(error => fail(current.token, "error", error.name || "AudioContextError"));
    }
  }

  function start(windowMs) {
    if (disposed) return;
    stop();
    const token = generation;
    status = "pending";
    if (!window.isSecureContext) {
      fail(token, "error", "insecure");
      return;
    }
    const Context = window.AudioContext || window.webkitAudioContext;
    if (!Context || !navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
      fail(token, "error", "unsupported");
      return;
    }
    try {
      const context = new Context();
      const current = { token, context, stream: null, source: null, analyser: null, buffer: null, count: 0, endedListeners: [] };
      resource = current;
      // Resume immediately while the Start/Retry click still has user activation.
      context.resume().catch(error => fail(token, "error", error.name || "AudioContextError"));
      const request = navigator.mediaDevices.getUserMedia({
        audio: { echoCancellation: true, noiseSuppression: true, autoGainControl: false },
        video: false,
      });
      Promise.resolve(request).then(async stream => {
        if (disposed || token !== generation) {
          stopTracks(stream);
          return;
        }
        current.stream = stream;
        if (!stream.getAudioTracks().some(track => track.readyState === "live")) {
          fail(token, "not-found", "NotFoundError");
          return;
        }
        current.source = context.createMediaStreamSource(stream);
        current.analyser = context.createAnalyser();
        const count = Math.max(32, Math.min(32768, Math.round(context.sampleRate * Number(windowMs) / 1000)));
        current.analyser.fftSize = 2 ** Math.ceil(Math.log2(count));
        current.analyser.smoothingTimeConstant = 0;
        current.count = count;
        current.buffer = new Float32Array(current.analyser.fftSize);
        // The analyser's output stays disconnected. Never connect the microphone to speakers.
        current.source.connect(current.analyser);
        stream.getAudioTracks().forEach(track => {
          const listener = () => fail(token, "not-found", "disconnected");
          current.endedListeners.push([track, listener]);
          track.addEventListener("ended", listener);
        });
        await context.resume();
        if (!disposed && token === generation) status = "active";
      }).catch(error => fail(token, errorStatus(error), error.name || "UnknownError"));
    } catch (error) {
      fail(token, errorStatus(error), error.name || "UnknownError");
    }
  }

  function sample() {
    timestamp = performance.now();
    const current = resource;
    rms = peak = 0;
    if (status === "active" && current) {
      if (current.context.state !== "running") {
        fail(current.token, "error", "interrupted");
      } else {
        current.analyser.getFloatTimeDomainData(current.buffer);
        let sum = 0;
        const offset = current.buffer.length - current.count;
        for (let i = offset; i < current.buffer.length; i += 1) {
          const value = Number.isFinite(current.buffer[i]) ? current.buffer[i] : 0;
          sum += value * value;
          peak = Math.max(peak, Math.abs(value));
        }
        rms = Math.sqrt(sum / current.count);
      }
    }
    return { status, errorCode, rms, peak, timestamp };
  }

  function dispose() {
    stop();
    disposed = true;
    document.removeEventListener("pointerdown", resumeOnGesture, true);
    document.removeEventListener("touchend", resumeOnGesture, true);
    window.removeEventListener("pagehide", stop);
    if (window.MatryoshkaMic === api) delete window.MatryoshkaMic;
  }

  const api = Object.freeze({
    start, sample, stop, dispose,
    get status() { return status; },
    get errorCode() { return errorCode; },
    get rms() { return rms; },
    get peak() { return peak; },
    get timestamp() { return timestamp; },
    get disposed() { return disposed; },
  });
  document.addEventListener("pointerdown", resumeOnGesture, true);
  document.addEventListener("touchend", resumeOnGesture, true);
  window.addEventListener("pagehide", stop);
  window.MatryoshkaMic = api;
})();
