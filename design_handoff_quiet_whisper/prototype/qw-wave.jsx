// Waveform, record button, and hold-space indicator

// ──────────────────────────────────────────────
// DotWave — soft pulsing dots driven by amplitude
// ──────────────────────────────────────────────
// Props:
//   theme      — current theme tokens
//   active     — bool, whether recording
//   amplitude  — live mic amplitude 0..1 (smoothed) or null for simulated
//   count      — number of dots
//   size       — "lg" | "md" | "sm"
// ──────────────────────────────────────────────
function DotWave({ theme, active, amplitude, count = 21, size = 'lg' }) {
  const [tick, setTick] = React.useState(0);
  const rafRef = React.useRef(null);

  // Animate when active (always — dots gently breathe using per-dot phases)
  React.useEffect(() => {
    let start = performance.now();
    const loop = (t) => {
      setTick((t - start) / 1000);
      rafRef.current = requestAnimationFrame(loop);
    };
    rafRef.current = requestAnimationFrame(loop);
    return () => cancelAnimationFrame(rafRef.current);
  }, []);

  const style = theme.waveStyle || 'dots';
  const sensitivity = theme.waveSensitivity ?? 1;

  const sizing = {
    lg: { base: 3, range: 8, gap: 10, h: 56 },
    md: { base: 2.5, range: 6, gap: 8, h: 40 },
    sm: { base: 2, range: 3.5, gap: 6, h: 24 },
  }[size];

  // Build per-element amplitude.
  const amps = [];
  for (let i = 0; i < count; i++) {
    if (!active) {
      const drift = (Math.sin(tick * 0.6 + i * 0.4) + 1) * 0.04;
      amps.push(0.08 + drift);
    } else {
      const amp = Math.min(1, (amplitude ?? 0.5) * sensitivity);
      const center = count / 2;
      const d = Math.abs(i - center) / center;
      const env = 1 - d * d * 0.45;
      const phase = Math.sin(tick * 3.2 + i * 0.5) * 0.5 + 0.5;
      const jitter = Math.sin(tick * 5.1 + i * 1.7) * 0.15;
      amps.push(Math.max(0.12, Math.min(1, amp * env * (0.55 + phase * 0.55) + jitter)));
    }
  }

  if (style === 'blob') {
    // Single breathing blob — radius pulses with amplitude
    const avg = amps.reduce((a, b) => a + b, 0) / amps.length;
    const r = sizing.h * 0.35 + avg * sizing.h * 0.28;
    const r2 = sizing.h * 0.28 + avg * sizing.h * 0.22;
    return (
      <div style={{
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        height: sizing.h, position: 'relative', width: '100%',
      }}>
        <div style={{
          position: 'absolute', width: r * 2, height: r * 2, borderRadius: '50%',
          background: active ? theme.dotActive : theme.dotIdle,
          opacity: active ? 0.18 : 0.12,
          transition: active ? 'none' : 'all 600ms cubic-bezier(.4,0,.2,1)',
          filter: 'blur(2px)',
        }} />
        <div style={{
          position: 'absolute', width: r2 * 2, height: r2 * 2, borderRadius: '50%',
          background: active ? theme.dotActive : theme.dotIdle,
          opacity: active ? 0.55 : 0.4,
          transition: active ? 'none' : 'all 600ms cubic-bezier(.4,0,.2,1)',
        }} />
      </div>
    );
  }

  if (style === 'bars') {
    return (
      <div style={{
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        gap: sizing.gap * 0.5, height: sizing.h,
      }}>
        {amps.map((a, i) => {
          const h = active ? Math.max(3, a * sizing.h * 0.95) : sizing.base * 1.5;
          return (
            <div key={i} style={{
              width: sizing.base + 1, height: h, borderRadius: 2,
              background: active ? theme.dotActive : theme.dotIdle,
              opacity: active ? 0.4 + a * 0.55 : 0.55,
              transition: active ? 'none' : 'all 600ms cubic-bezier(.4,0,.2,1)',
            }} />
          );
        })}
      </div>
    );
  }

  // default: dots
  return (
    <div style={{
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      gap: sizing.gap, height: sizing.h,
    }}>
      {amps.map((a, i) => {
        const s = sizing.base + a * sizing.range;
        return (
          <div key={i} style={{
            width: s, height: s, borderRadius: '50%',
            background: active ? theme.dotActive : theme.dotIdle,
            opacity: active ? 0.35 + a * 0.6 : 0.7,
            transition: active ? 'none' : 'all 600ms cubic-bezier(.4,0,.2,1)',
          }} />
        );
      })}
    </div>
  );
}

// ──────────────────────────────────────────────
// RecordButton — big soft circle. Changes from circle (idle) to square (stop)
// when active. Has a soft halo when active.
// ──────────────────────────────────────────────
function RecordButton({ theme, active, onClick, size = 72 }) {
  const inner = active ? size * 0.28 : size * 0.32;
  const [hover, setHover] = React.useState(false);

  return (
    <button
      onClick={onClick}
      onMouseEnter={() => setHover(true)}
      onMouseLeave={() => setHover(false)}
      style={{
        width: size, height: size, borderRadius: '50%',
        background: theme.recordBg, color: theme.recordFg,
        border: 'none', cursor: 'pointer',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        position: 'relative',
        boxShadow: active
          ? `0 0 0 8px ${theme.dotIdle}, 0 8px 32px ${theme.mode === 'dark' ? 'rgba(0,0,0,0.4)' : 'rgba(26,24,21,0.15)'}`
          : hover
            ? `0 4px 20px ${theme.mode === 'dark' ? 'rgba(0,0,0,0.3)' : 'rgba(26,24,21,0.12)'}`
            : `0 2px 12px ${theme.mode === 'dark' ? 'rgba(0,0,0,0.25)' : 'rgba(26,24,21,0.08)'}`,
        transform: hover && !active ? 'translateY(-1px)' : 'none',
        transition: 'all 220ms cubic-bezier(.4,0,.2,1)',
      }}
      aria-label={active ? 'Stop recording' : 'Start recording'}
    >
      <div style={{
        width: inner, height: inner,
        borderRadius: active ? 3 : '50%',
        background: theme.recordFg,
        transition: 'all 180ms cubic-bezier(.4,0,.2,1)',
      }} />
    </button>
  );
}

// ──────────────────────────────────────────────
// SmallRecordButton — compact version for the footer bar
// ──────────────────────────────────────────────
function SmallRecordButton({ theme, active, onClick }) {
  return <RecordButton theme={theme} active={active} onClick={onClick} size={44} />;
}

// ──────────────────────────────────────────────
// Microphone hook — tries to use real mic, falls back to simulated amplitude
// Returns { amplitude: number|null, start(), stop() }
// ──────────────────────────────────────────────
function useMicAmplitude() {
  const [amplitude, setAmplitude] = React.useState(0);
  const streamRef = React.useRef(null);
  const ctxRef = React.useRef(null);
  const analyserRef = React.useRef(null);
  const rafRef = React.useRef(null);
  const simRef = React.useRef(null);
  const usingRealRef = React.useRef(false);

  const stop = React.useCallback(() => {
    if (rafRef.current) cancelAnimationFrame(rafRef.current);
    if (simRef.current) clearInterval(simRef.current);
    if (streamRef.current) streamRef.current.getTracks().forEach(t => t.stop());
    if (ctxRef.current) ctxRef.current.close?.();
    streamRef.current = null;
    ctxRef.current = null;
    analyserRef.current = null;
    rafRef.current = null;
    simRef.current = null;
    usingRealRef.current = false;
    setAmplitude(0);
  }, []);

  const startSim = React.useCallback(() => {
    // smooth random walk simulating natural speech
    let a = 0.3;
    let target = 0.4;
    let ticks = 0;
    simRef.current = setInterval(() => {
      ticks++;
      if (ticks % 6 === 0) {
        target = 0.15 + Math.random() * 0.7;
      }
      a += (target - a) * 0.25;
      setAmplitude(a);
    }, 60);
  }, []);

  const start = React.useCallback(async () => {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      streamRef.current = stream;
      const AudioCtx = window.AudioContext || window.webkitAudioContext;
      const ctx = new AudioCtx();
      ctxRef.current = ctx;
      const source = ctx.createMediaStreamSource(stream);
      const analyser = ctx.createAnalyser();
      analyser.fftSize = 512;
      analyser.smoothingTimeConstant = 0.75;
      source.connect(analyser);
      analyserRef.current = analyser;
      usingRealRef.current = true;

      const data = new Uint8Array(analyser.frequencyBinCount);
      const loop = () => {
        analyser.getByteTimeDomainData(data);
        // RMS around 128
        let sum = 0;
        for (let i = 0; i < data.length; i++) {
          const v = (data[i] - 128) / 128;
          sum += v * v;
        }
        const rms = Math.sqrt(sum / data.length);
        // amplify — normal speech sits around 0.05-0.15 RMS
        const boosted = Math.min(1, rms * 4.5);
        setAmplitude(prev => prev + (boosted - prev) * 0.35);
        rafRef.current = requestAnimationFrame(loop);
      };
      rafRef.current = requestAnimationFrame(loop);
    } catch (e) {
      // fallback to simulated
      startSim();
    }
  }, [startSim]);

  React.useEffect(() => stop, [stop]);

  return { amplitude, start, stop };
}

Object.assign(window, { DotWave, RecordButton, SmallRecordButton, useMicAmplitude });
