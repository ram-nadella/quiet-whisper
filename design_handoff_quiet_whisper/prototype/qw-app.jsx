// Main app — ties everything together.
// Flow:
//   1. user opens app → empty state with big record button
//   2. click button or hold space → recording (waveform, timer)
//   3. release / click stop → transcribing (brief) → text appears
//   4. text is editable in-place; snippet saved to history
//   5. sidebar (toggleable) shows grouped history, delete on hover
//   6. settings modal: model, language, auto-punct, dark mode

const FAKE_TRANSCRIPTS = [
  "I want to write something about the way mornings have changed since I started working from home. The light in the kitchen at seven is different than I remembered. Everything moves slower, which is both the point and the problem.",
  "Reminder to self — book the flights for the wedding before prices go up. Check whether Sarah needs a ride from the airport. Figure out a gift. And probably get a haircut that week.",
  "The argument for simpler software isn't nostalgia. It's that every feature costs maintenance, cognitive load, and a little of the product's soul. Not every product needs to be big. Some should stay exactly the size they are.",
  "I had an idea while walking — what if the calendar app just showed you the next three things, instead of everything? Most of the time you don't need everything. You need to know what's now, what's next, and what's after that. The rest is noise.",
];

function QuietWhisper({ tweaks }) {
  const [dark, setDark] = React.useState(() => {
    const saved = localStorage.getItem('qw-dark');
    return saved === 'true';
  });
  // Build theme: base by mode, then overlay accent tint from tweaks.
  const baseTheme = dark ? darkTheme : lightTheme;
  const theme = React.useMemo(() => {
    const t = { ...baseTheme };
    const accents = {
      ink:    { bg: t.recordBg, fg: t.recordFg, dotActive: t.dotActive },
      coral:  { bg: 'oklch(64% 0.13 35)', fg: '#fbf7f0', dotActive: 'oklch(64% 0.13 35)' },
      sage:   { bg: 'oklch(52% 0.06 150)', fg: '#f6f4ef', dotActive: 'oklch(52% 0.06 150)' },
      indigo: { bg: 'oklch(45% 0.10 265)', fg: '#f3f1ec', dotActive: 'oklch(50% 0.10 265)' },
    };
    const a = accents[tweaks.accent] || accents.ink;
    t.recordBg = a.bg;
    t.recordFg = a.fg;
    t.dotActive = a.dotActive;
    t.readingFont = tweaks.readingFont === 'iowan' ? '"Iowan Old Style", Georgia, serif'
      : tweaks.readingFont === 'georgia' ? 'Georgia, serif'
      : '"Fraunces", "Iowan Old Style", Georgia, serif';
    t.readingSize = tweaks.readingSize;
    t.density = tweaks.density;
    t.waveStyle = tweaks.waveStyle;
    t.waveSensitivity = tweaks.waveSensitivity;
    return t;
  }, [baseTheme, tweaks]);

  const [sidebarOpen, setSidebarOpen] = React.useState(() => {
    const saved = localStorage.getItem('qw-sidebar');
    return saved === null ? false : saved === 'true';  // closed by default per user
  });
  const [settingsOpen, setSettingsOpen] = React.useState(false);
  const [settings, setSettings] = React.useState({
    model: 'small',
    autoPunct: true,
  });

  const [snippets, setSnippets] = React.useState(seedSnippets);
  const [selectedId, setSelectedId] = React.useState(null);
  const [draft, setDraft] = React.useState(null); // { title, text, createdAt, durationSec } in-progress

  // Recording state machine: 'idle' | 'recording' | 'transcribing'
  const [recState, setRecState] = React.useState('idle');
  const [recStart, setRecStart] = React.useState(null);
  const [recElapsed, setRecElapsed] = React.useState(0);
  const { amplitude, start: micStart, stop: micStop } = useMicAmplitude();

  // Persist dark + sidebar
  React.useEffect(() => localStorage.setItem('qw-dark', String(dark)), [dark]);
  React.useEffect(() => localStorage.setItem('qw-sidebar', String(sidebarOpen)), [sidebarOpen]);

  // Elapsed timer while recording
  React.useEffect(() => {
    if (recState !== 'recording') return;
    const id = setInterval(() => setRecElapsed(Date.now() - recStart), 100);
    return () => clearInterval(id);
  }, [recState, recStart]);

  // ── Recording actions ────────────────────────────
  const startRecording = React.useCallback(() => {
    if (recState !== 'idle') return;
    setRecStart(Date.now());
    setRecElapsed(0);
    setRecState('recording');
    setSelectedId(null);
    setDraft(null);
    micStart();
  }, [recState, micStart]);

  const stopRecording = React.useCallback(() => {
    if (recState !== 'recording') return;
    micStop();
    const dur = Math.max(1, Math.round((Date.now() - recStart) / 1000));
    setRecState('transcribing');
    // simulate local transcription delay
    const delay = Math.min(2200, 600 + dur * 60);
    setTimeout(() => {
      const text = FAKE_TRANSCRIPTS[Math.floor(Math.random() * FAKE_TRANSCRIPTS.length)];
      const title = text.split(/[.!?]/)[0].slice(0, 50).trim() || 'Untitled';
      const newSnippet = {
        id: 'n' + Date.now(),
        title, text,
        createdAt: Date.now(),
        durationSec: dur,
      };
      setSnippets(prev => [newSnippet, ...prev]);
      setSelectedId(newSnippet.id);
      setRecState('idle');
    }, delay);
  }, [recState, recStart, micStop]);

  const toggleRecording = React.useCallback(() => {
    if (recState === 'idle') startRecording();
    else if (recState === 'recording') stopRecording();
  }, [recState, startRecording, stopRecording]);

  // ── Hold-space to record ─────────────────────────
  React.useEffect(() => {
    const isTypingTarget = (el) =>
      el && (el.tagName === 'INPUT' || el.tagName === 'TEXTAREA' || el.isContentEditable);

    let held = false;
    const onDown = (e) => {
      if (e.code !== 'Space' || e.repeat) return;
      if (isTypingTarget(e.target)) return;
      if (settingsOpen) return;
      e.preventDefault();
      if (recState === 'idle') {
        held = true;
        startRecording();
      }
    };
    const onUp = (e) => {
      if (e.code !== 'Space') return;
      if (held && recState === 'recording') {
        held = false;
        stopRecording();
      } else {
        held = false;
      }
    };
    window.addEventListener('keydown', onDown);
    window.addEventListener('keyup', onUp);
    return () => {
      window.removeEventListener('keydown', onDown);
      window.removeEventListener('keyup', onUp);
    };
  }, [recState, startRecording, stopRecording, settingsOpen]);

  // ── Snippet ops ──────────────────────────────────
  const selectedSnippet = snippets.find(s => s.id === selectedId);
  const updateSnippet = (id, patch) => {
    setSnippets(prev => prev.map(s => s.id === id ? { ...s, ...patch } : s));
  };
  const deleteSnippet = (id) => {
    setSnippets(prev => prev.filter(s => s.id !== id));
    if (selectedId === id) setSelectedId(null);
  };
  const newNote = () => {
    setSelectedId(null);
    if (!sidebarOpen) setSidebarOpen(true);
  };

  // ── Settings updates (theme toggle piggybacks) ───
  const onSettingsChange = (next) => {
    if ('dark' in next) {
      setDark(next.dark);
      const { dark: _, ...rest } = next;
      setSettings(rest);
    } else {
      setSettings(next);
    }
  };

  return (
    <div style={{
      width: '100%', height: '100%',
      background: theme.bg,
      display: 'flex', flexDirection: 'row',
      position: 'relative', overflow: 'hidden',
      transition: 'background 240ms ease',
    }}>
      {/* Sidebar */}
      <div style={{
        width: sidebarOpen ? 260 : 0,
        overflow: 'hidden',
        transition: 'width 260ms cubic-bezier(.4,0,.2,1)',
        flexShrink: 0,
      }}>
        <Sidebar
          theme={theme}
          snippets={snippets}
          selectedId={selectedId}
          onSelect={(id) => { setSelectedId(id); }}
          onDelete={deleteSnippet}
          onNew={newNote}
          onClose={() => setSidebarOpen(false)}
        />
      </div>

      {/* Main column */}
      <div style={{
        flex: 1, display: 'flex', flexDirection: 'column',
        minWidth: 0, position: 'relative',
      }}>
        {/* Top bar */}
        <TopBar
          theme={theme}
          sidebarOpen={sidebarOpen}
          onToggleSidebar={() => setSidebarOpen(o => !o)}
          onOpenSettings={() => setSettingsOpen(true)}
          onToggleDark={() => setDark(d => !d)}
          dark={dark}
        />

        {/* Content */}
        <div style={{ flex: 1, overflow: 'hidden', display: 'flex' }}>
          {recState === 'idle' && !selectedSnippet && (
            <EmptyStage theme={theme} onRecord={toggleRecording} />
          )}
          {recState === 'recording' && (
            <RecordingStage theme={theme} amplitude={amplitude} elapsed={recElapsed} onStop={toggleRecording} />
          )}
          {recState === 'transcribing' && (
            <TranscribingStage theme={theme} />
          )}
          {recState === 'idle' && selectedSnippet && (
            <EditorStage
              key={selectedSnippet.id}
              theme={theme}
              snippet={selectedSnippet}
              onUpdate={(patch) => updateSnippet(selectedSnippet.id, patch)}
              onRecord={toggleRecording}
            />
          )}
        </div>
      </div>

      {/* Settings modal */}
      {settingsOpen && (
        <SettingsModal
          theme={theme}
          settings={{ ...settings, dark }}
          onChange={onSettingsChange}
          onClose={() => setSettingsOpen(false)}
        />
      )}
    </div>
  );
}

// ──────────────────────────────────────────────
// Top bar — traffic lights + title + right-side controls
// ──────────────────────────────────────────────
function TopBar({ theme, sidebarOpen, onToggleSidebar, onOpenSettings, onToggleDark, dark }) {
  return (
    <div style={{
      height: 44, flexShrink: 0,
      display: 'flex', alignItems: 'center',
      padding: sidebarOpen ? '0 12px' : '0 12px 0 82px',
      borderBottom: `1px solid ${theme.line}`,
      background: theme.bg,
      transition: 'padding 260ms cubic-bezier(.4,0,.2,1), background 240ms ease',
      position: 'relative',
    }}>
      {!sidebarOpen && (
        <IconButton theme={theme} onClick={onToggleSidebar} title="Show sidebar">
          <Icon.Sidebar />
        </IconButton>
      )}
      <div style={{ flex: 1 }} />
      <div style={{
        position: 'absolute', left: '50%', top: '50%',
        transform: 'translate(-50%, -50%)',
        fontFamily: F_SERIF, fontSize: 14,
        color: theme.mute, letterSpacing: 0.3,
        fontStyle: 'italic', pointerEvents: 'none',
      }}>
        Quiet Whisper
      </div>
      <IconButton theme={theme} onClick={onToggleDark} title={dark ? 'Light mode' : 'Dark mode'}>
        {dark ? <Icon.Sun /> : <Icon.Moon />}
      </IconButton>
      <IconButton theme={theme} onClick={onOpenSettings} title="Settings">
        <Icon.Settings />
      </IconButton>
    </div>
  );
}

// ──────────────────────────────────────────────
// EmptyStage — first screen, big record button
// ──────────────────────────────────────────────
function EmptyStage({ theme, onRecord }) {
  return (
    <div style={{
      flex: 1, display: 'flex', flexDirection: 'column',
      alignItems: 'center', justifyContent: 'center',
      padding: 40,
    }}>
      <div style={{
        fontFamily: F_SERIF, fontSize: 38, fontWeight: 400,
        color: theme.ink, letterSpacing: -0.8,
        marginBottom: 14, textAlign: 'center',
      }}>
        A quiet place to think out loud.
      </div>
      <div style={{
        fontFamily: F_SERIF, fontStyle: 'italic', fontSize: 15,
        color: theme.mute, marginBottom: 56,
        textAlign: 'center', lineHeight: 1.55, maxWidth: 420,
      }}>
        Press and hold <KeyCap theme={theme}>space</KeyCap>, or click the button.
        Take your time — there's no rush.
      </div>
      <DotWave theme={theme} active={false} size="lg" />
      <div style={{ height: 40 }} />
      <RecordButton theme={theme} active={false} onClick={onRecord} />
    </div>
  );
}

function KeyCap({ theme, children }) {
  return (
    <kbd style={{
      fontFamily: F_MONO, fontSize: 11,
      padding: '2px 6px',
      border: `1px solid ${theme.line}`,
      borderRadius: 4, background: theme.panel,
      color: theme.inkSoft, margin: '0 2px',
      fontStyle: 'normal',
    }}>{children}</kbd>
  );
}

// ──────────────────────────────────────────────
// RecordingStage — waveform + elapsed + stop
// ──────────────────────────────────────────────
function RecordingStage({ theme, amplitude, elapsed, onStop }) {
  const sec = Math.floor(elapsed / 1000);
  const mm = Math.floor(sec / 60).toString().padStart(2, '0');
  const ss = (sec % 60).toString().padStart(2, '0');
  const ms = Math.floor((elapsed % 1000) / 100);

  return (
    <div style={{
      flex: 1, display: 'flex', flexDirection: 'column',
      alignItems: 'center', justifyContent: 'center',
      padding: 40,
    }}>
      <div style={{
        fontFamily: F_MONO, fontSize: 11,
        color: theme.mute, letterSpacing: 1.5,
        textTransform: 'uppercase', marginBottom: 14,
        display: 'flex', alignItems: 'center', gap: 8,
      }}>
        <span style={{
          width: 6, height: 6, borderRadius: '50%',
          background: theme.ink, opacity: 0.6,
          animation: 'qw-pulse 1.4s ease-in-out infinite',
        }} />
        listening
      </div>
      <div style={{
        fontFamily: F_SERIF, fontStyle: 'italic', fontSize: 18,
        color: theme.inkSoft, marginBottom: 44, textAlign: 'center',
      }}>
        Take your time.
      </div>
      <DotWave theme={theme} active={true} amplitude={amplitude} size="lg" />
      <div style={{ height: 36 }} />
      <div style={{
        fontFamily: F_MONO, fontSize: 22, fontWeight: 400,
        color: theme.ink, letterSpacing: 0.5,
        marginBottom: 28, fontVariantNumeric: 'tabular-nums',
      }}>
        {mm}:{ss}<span style={{ color: theme.mute }}>.{ms}</span>
      </div>
      <RecordButton theme={theme} active={true} onClick={onStop} />
      <div style={{
        fontFamily: F_MONO, fontSize: 10.5, color: theme.mute,
        marginTop: 24, letterSpacing: 0.8,
      }}>
        release space to stop
      </div>
    </div>
  );
}

// ──────────────────────────────────────────────
// TranscribingStage — brief interstitial
// ──────────────────────────────────────────────
function TranscribingStage({ theme }) {
  return (
    <div style={{
      flex: 1, display: 'flex', flexDirection: 'column',
      alignItems: 'center', justifyContent: 'center', padding: 40,
    }}>
      <div style={{
        fontFamily: F_SERIF, fontStyle: 'italic', fontSize: 22,
        color: theme.inkSoft, marginBottom: 32,
      }}>
        Transcribing…
      </div>
      <TranscribeSpinner theme={theme} />
    </div>
  );
}

function TranscribeSpinner({ theme }) {
  // Three dots, staggered opacity
  const [t, setT] = React.useState(0);
  React.useEffect(() => {
    const id = setInterval(() => setT(x => x + 1), 180);
    return () => clearInterval(id);
  }, []);
  return (
    <div style={{ display: 'flex', gap: 10 }}>
      {[0, 1, 2].map(i => (
        <div key={i} style={{
          width: 6, height: 6, borderRadius: '50%',
          background: theme.ink,
          opacity: ((t - i) % 3 + 3) % 3 === 0 ? 0.9 : 0.25,
          transition: 'opacity 180ms ease',
        }} />
      ))}
    </div>
  );
}

// ──────────────────────────────────────────────
// EditorStage — shows snippet title + text, both editable.
// Footer: small waveform (idle) + small record button (adds to this note).
// ──────────────────────────────────────────────
function EditorStage({ theme, snippet, onUpdate, onRecord }) {
  const [title, setTitle] = React.useState(snippet.title);
  const [text, setText] = React.useState(snippet.text);
  const [copied, setCopied] = React.useState(false);

  // Sync down when snippet changes
  React.useEffect(() => {
    setTitle(snippet.title);
    setText(snippet.text);
  }, [snippet.id]);

  // Debounced save
  React.useEffect(() => {
    const id = setTimeout(() => {
      if (title !== snippet.title || text !== snippet.text) {
        onUpdate({ title, text });
      }
    }, 300);
    return () => clearTimeout(id);
  }, [title, text]);

  const taRef = React.useRef(null);
  // auto-grow
  React.useEffect(() => {
    const ta = taRef.current;
    if (!ta) return;
    ta.style.height = 'auto';
    ta.style.height = ta.scrollHeight + 'px';
  }, [text]);

  const wordCount = text.trim() ? text.trim().split(/\s+/).length : 0;

  const copyText = async () => {
    try {
      await navigator.clipboard.writeText(text);
      setCopied(true);
      setTimeout(() => setCopied(false), 1600);
    } catch {}
  };

  return (
    <div style={{
      flex: 1, display: 'flex', flexDirection: 'column',
      minHeight: 0, position: 'relative',
    }}>
      {/* Scrollable content */}
      <div style={{
        flex: 1, overflow: 'auto',
        padding: '48px 64px 160px',
      }}>
        <div style={{ maxWidth: 680, margin: '0 auto' }}>
          {/* Meta */}
          <div style={{
            fontFamily: F_MONO, fontSize: 10.5,
            color: theme.mute, letterSpacing: 1.2,
            textTransform: 'uppercase', marginBottom: 14,
            display: 'flex', gap: 10,
          }}>
            <span>{formatDate(snippet.createdAt)}</span>
            <span style={{ opacity: 0.5 }}>·</span>
            <span>{formatTime(snippet.createdAt)}</span>
            <span style={{ opacity: 0.5 }}>·</span>
            <span>{formatDuration(snippet.durationSec)}</span>
          </div>

          {/* Title — editable */}
          <textarea
            value={title}
            onChange={e => setTitle(e.target.value)}
            rows={1}
            spellCheck={false}
            style={{
              width: '100%', border: 'none', outline: 'none',
              background: 'transparent', color: theme.ink,
              fontFamily: theme.readingFont || F_SERIF,
              fontSize: (theme.readingSize || 18) + 16, fontWeight: 400,
              letterSpacing: -0.6, lineHeight: 1.15,
              resize: 'none', padding: 0, marginBottom: 22,
              overflow: 'hidden',
            }}
          />

          {/* Body — editable */}
          <textarea
            ref={taRef}
            value={text}
            onChange={e => setText(e.target.value)}
            spellCheck={true}
            style={{
              width: '100%', minHeight: 200, border: 'none', outline: 'none',
              background: 'transparent', color: theme.ink,
              fontFamily: theme.readingFont || F_SERIF,
              fontSize: theme.readingSize || 18, fontWeight: 400,
              lineHeight: theme.density === 'compact' ? 1.45
                : theme.density === 'comfy' ? 1.85 : 1.65,
              letterSpacing: 0.1,
              resize: 'none', padding: 0, overflow: 'hidden',
              textWrap: 'pretty',
            }}
          />

          {/* footer meta */}
          <div style={{
            marginTop: 32,
            fontFamily: F_MONO, fontSize: 10.5,
            color: theme.mute, letterSpacing: 0.4,
            display: 'flex', gap: 10,
          }}>
            <span>{wordCount} words</span>
            <span style={{ opacity: 0.5 }}>·</span>
            <span>saved</span>
          </div>
        </div>
      </div>

      {/* Footer bar — pinned, contains waveform + record + copy */}
      <div style={{
        position: 'absolute', left: 0, right: 0, bottom: 0,
        padding: '16px 24px 20px',
        background: `linear-gradient(to bottom, transparent, ${theme.bg} 30%)`,
        display: 'flex', alignItems: 'center', gap: 14,
        justifyContent: 'center',
      }}>
        <div style={{
          display: 'flex', alignItems: 'center', gap: 14,
          padding: '10px 14px',
          background: theme.panel,
          border: `1px solid ${theme.line}`,
          borderRadius: 100,
          boxShadow: theme.shadow,
        }}>
          <button
            onClick={copyText}
            title="Copy"
            style={{
              width: 34, height: 34, borderRadius: '50%',
              background: 'transparent', color: theme.inkSoft,
              border: 'none', cursor: 'pointer',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
            }}
          >
            {copied ? <Icon.Check /> : <Icon.Copy />}
          </button>
          <div style={{ width: 1, height: 18, background: theme.line }} />
          <DotWave theme={theme} active={false} size="sm" count={15} />
          <div style={{ width: 1, height: 18, background: theme.line }} />
          <SmallRecordButton theme={theme} active={false} onClick={onRecord} />
        </div>
      </div>
    </div>
  );
}

function formatDate(ts) {
  const d = new Date(ts);
  const now = new Date();
  const diff = (now - d) / (24 * 3600 * 1000);
  if (diff < 1 && d.getDate() === now.getDate()) return 'Today';
  if (diff < 2) return 'Yesterday';
  return d.toLocaleDateString(undefined, { month: 'long', day: 'numeric' });
}

Object.assign(window, { QuietWhisper });
