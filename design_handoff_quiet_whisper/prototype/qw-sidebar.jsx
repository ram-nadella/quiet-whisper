// Sidebar + Settings modal for Quiet Whisper

// Date grouping helper
function groupByDate(snippets) {
  const now = new Date();
  const startOfToday = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
  const startOfYesterday = startOfToday - 24 * 3600 * 1000;
  const startOfWeek = startOfToday - 7 * 24 * 3600 * 1000;

  const groups = { Today: [], Yesterday: [], 'This week': [], Earlier: [] };
  for (const s of snippets) {
    if (s.createdAt >= startOfToday) groups.Today.push(s);
    else if (s.createdAt >= startOfYesterday) groups.Yesterday.push(s);
    else if (s.createdAt >= startOfWeek) groups['This week'].push(s);
    else groups.Earlier.push(s);
  }
  // filter empty
  return Object.entries(groups).filter(([, arr]) => arr.length > 0);
}

function formatTime(ts) {
  const d = new Date(ts);
  const hours = d.getHours();
  const mins = d.getMinutes().toString().padStart(2, '0');
  const ampm = hours >= 12 ? 'pm' : 'am';
  const h12 = hours % 12 || 12;
  return `${h12}:${mins} ${ampm}`;
}

function formatDuration(sec) {
  const m = Math.floor(sec / 60);
  const s = sec % 60;
  return m > 0 ? `${m}:${s.toString().padStart(2, '0')}` : `${s}s`;
}

// ──────────────────────────────────────────────
// SidebarItem — one snippet row
// ──────────────────────────────────────────────
function SidebarItem({ theme, snippet, selected, onSelect, onDelete }) {
  const [hover, setHover] = React.useState(false);
  const [confirmDel, setConfirmDel] = React.useState(false);

  return (
    <div
      onClick={() => onSelect(snippet.id)}
      onMouseEnter={() => setHover(true)}
      onMouseLeave={() => { setHover(false); setConfirmDel(false); }}
      style={{
        padding: '10px 14px',
        borderRadius: 6,
        background: selected ? theme.selected : hover ? theme.hover : 'transparent',
        cursor: 'pointer',
        position: 'relative',
        transition: 'background 120ms ease',
        marginBottom: 1,
      }}
    >
      <div style={{
        fontFamily: F_UI, fontSize: 13, fontWeight: 500,
        color: theme.ink, marginBottom: 3,
        whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis',
        paddingRight: hover ? 22 : 0,
        transition: 'padding 120ms ease',
      }}>
        {snippet.title}
      </div>
      <div style={{
        fontFamily: F_MONO, fontSize: 10.5,
        color: theme.mute, letterSpacing: 0.4,
        display: 'flex', gap: 8,
      }}>
        <span>{formatTime(snippet.createdAt)}</span>
        <span style={{ opacity: 0.5 }}>·</span>
        <span>{formatDuration(snippet.durationSec)}</span>
      </div>

      {/* delete button — reveals on hover */}
      {hover && (
        <button
          onClick={(e) => {
            e.stopPropagation();
            if (confirmDel) {
              onDelete(snippet.id);
            } else {
              setConfirmDel(true);
              setTimeout(() => setConfirmDel(false), 2000);
            }
          }}
          style={{
            position: 'absolute', top: 10, right: 10,
            width: 20, height: 20, borderRadius: 4,
            border: 'none', cursor: 'pointer',
            background: confirmDel ? theme.danger : 'transparent',
            color: confirmDel ? theme.recordFg : theme.mute,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            transition: 'all 120ms ease',
          }}
          aria-label={confirmDel ? 'Confirm delete' : 'Delete'}
          title={confirmDel ? 'Click again to delete' : 'Delete'}
        >
          <Icon.Trash size={12} />
        </button>
      )}
    </div>
  );
}

// ──────────────────────────────────────────────
// Sidebar
// ──────────────────────────────────────────────
function Sidebar({ theme, snippets, selectedId, onSelect, onDelete, onNew, onClose }) {
  const groups = groupByDate(snippets);

  return (
    <div style={{
      width: 260, height: '100%',
      background: theme.sidebar,
      borderRight: `1px solid ${theme.line}`,
      display: 'flex', flexDirection: 'column',
      flexShrink: 0,
    }}>
      {/* Top bar — leaves room for traffic lights */}
      <div style={{
        height: 44, display: 'flex', alignItems: 'center',
        justifyContent: 'space-between',
        padding: '0 12px 0 82px',
        flexShrink: 0,
      }}>
        <div style={{
          fontFamily: F_SERIF, fontSize: 15, fontWeight: 400,
          color: theme.ink, fontStyle: 'italic',
          letterSpacing: 0.1,
        }}>
          Notes
        </div>
        <div style={{ display: 'flex', gap: 2 }}>
          <IconButton theme={theme} onClick={onNew} title="New note">
            <Icon.Plus />
          </IconButton>
          <IconButton theme={theme} onClick={onClose} title="Close sidebar">
            <Icon.Sidebar />
          </IconButton>
        </div>
      </div>

      {/* List */}
      <div style={{ flex: 1, overflow: 'auto', padding: '4px 8px 20px' }}>
        {groups.length === 0 && (
          <div style={{
            padding: '40px 14px', textAlign: 'center',
            fontFamily: F_SERIF, fontStyle: 'italic',
            fontSize: 13, color: theme.mute, lineHeight: 1.5,
          }}>
            Nothing here yet.<br/>Press the button to start.
          </div>
        )}
        {groups.map(([label, items]) => (
          <div key={label} style={{ marginBottom: 16 }}>
            <div style={{
              padding: '10px 14px 6px',
              fontFamily: F_MONO, fontSize: 10, fontWeight: 500,
              color: theme.mute, letterSpacing: 1.2,
              textTransform: 'uppercase',
            }}>
              {label}
            </div>
            {items.map(s => (
              <SidebarItem
                key={s.id}
                theme={theme}
                snippet={s}
                selected={s.id === selectedId}
                onSelect={onSelect}
                onDelete={onDelete}
              />
            ))}
          </div>
        ))}
      </div>
    </div>
  );
}

// ──────────────────────────────────────────────
// IconButton — small ghost button used in toolbars
// ──────────────────────────────────────────────
function IconButton({ theme, onClick, children, title, active = false }) {
  const [hover, setHover] = React.useState(false);
  return (
    <button
      onClick={onClick}
      onMouseEnter={() => setHover(true)}
      onMouseLeave={() => setHover(false)}
      title={title}
      aria-label={title}
      style={{
        width: 28, height: 28, borderRadius: 6,
        background: active ? theme.active : hover ? theme.hover : 'transparent',
        color: theme.inkSoft,
        border: 'none', cursor: 'pointer',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        transition: 'background 120ms ease',
      }}
    >
      {children}
    </button>
  );
}

// ──────────────────────────────────────────────
// Settings modal — model, language, auto-punct, theme
// ──────────────────────────────────────────────
function SettingsModal({ theme, settings, onChange, onClose }) {
  const models = [
    { id: 'tiny', label: 'Whisper Tiny', meta: '39M · fastest · lowest accuracy' },
    { id: 'base', label: 'Whisper Base', meta: '74M · fast' },
    { id: 'small', label: 'Whisper Small', meta: '244M · balanced', recommended: true },
    { id: 'medium', label: 'Whisper Medium', meta: '769M · accurate · slower' },
    { id: 'voxtral', label: 'Voxtral Mini', meta: 'Mistral · 1B · experimental' },
  ];

  return (
    <div
      onClick={onClose}
      style={{
        position: 'absolute', inset: 0, zIndex: 10,
        background: theme.mode === 'dark' ? 'rgba(0,0,0,0.5)' : 'rgba(26,24,21,0.25)',
        backdropFilter: 'blur(4px)',
        WebkitBackdropFilter: 'blur(4px)',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        animation: 'qw-fade 160ms ease',
      }}
    >
      <div
        onClick={e => e.stopPropagation()}
        style={{
          width: 480, maxWidth: '90%',
          background: theme.panel,
          borderRadius: 12,
          boxShadow: theme.shadow,
          border: `1px solid ${theme.line}`,
          overflow: 'hidden',
          animation: 'qw-rise 200ms cubic-bezier(.4,0,.2,1)',
        }}
      >
        {/* Header */}
        <div style={{
          padding: '20px 24px 16px',
          display: 'flex', alignItems: 'center', justifyContent: 'space-between',
          borderBottom: `1px solid ${theme.lineSoft}`,
        }}>
          <div style={{
            fontFamily: F_SERIF, fontSize: 22, fontWeight: 400,
            color: theme.ink, letterSpacing: -0.2,
          }}>
            Settings
          </div>
          <IconButton theme={theme} onClick={onClose} title="Close">
            <Icon.Close />
          </IconButton>
        </div>

        {/* Body */}
        <div style={{ padding: '20px 24px 24px', maxHeight: 440, overflow: 'auto' }}>
          {/* Model */}
          <SettingGroup theme={theme} label="Transcription model" hint="All models run locally. Nothing leaves this device.">
            <div style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
              {models.map(m => (
                <ModelRow
                  key={m.id}
                  theme={theme}
                  model={m}
                  selected={settings.model === m.id}
                  onClick={() => onChange({ ...settings, model: m.id })}
                />
              ))}
            </div>
          </SettingGroup>

          {/* Language */}
          <SettingGroup theme={theme} label="Language">
            <SelectRow
              theme={theme}
              value="English (US)"
              hint="More languages coming soon."
            />
          </SettingGroup>

          {/* Auto-punctuation */}
          <SettingGroup theme={theme} label="Transcription">
            <ToggleRow
              theme={theme}
              label="Auto-insert punctuation"
              hint="Adds commas, periods, and capitals from speech patterns."
              value={settings.autoPunct}
              onChange={v => onChange({ ...settings, autoPunct: v })}
            />
          </SettingGroup>

          {/* Appearance */}
          <SettingGroup theme={theme} label="Appearance" last>
            <ToggleRow
              theme={theme}
              label="Dark mode"
              hint="Inverted paper — warm near-black with ivory ink."
              value={theme.mode === 'dark'}
              onChange={v => onChange({ ...settings, dark: v })}
            />
          </SettingGroup>
        </div>
      </div>
    </div>
  );
}

function SettingGroup({ theme, label, hint, children, last = false }) {
  return (
    <div style={{ marginBottom: last ? 0 : 22 }}>
      <div style={{
        fontFamily: F_MONO, fontSize: 10.5, fontWeight: 500,
        color: theme.mute, letterSpacing: 1.2,
        textTransform: 'uppercase', marginBottom: 8,
      }}>
        {label}
      </div>
      {hint && (
        <div style={{
          fontFamily: F_SERIF, fontStyle: 'italic', fontSize: 12.5,
          color: theme.inkSoft, marginBottom: 10, lineHeight: 1.45,
        }}>
          {hint}
        </div>
      )}
      {children}
    </div>
  );
}

function ModelRow({ theme, model, selected, onClick }) {
  const [hover, setHover] = React.useState(false);
  return (
    <div
      onClick={onClick}
      onMouseEnter={() => setHover(true)}
      onMouseLeave={() => setHover(false)}
      style={{
        padding: '10px 12px',
        borderRadius: 6,
        background: selected ? theme.selected : hover ? theme.hover : 'transparent',
        cursor: 'pointer',
        display: 'flex', alignItems: 'center', gap: 10,
        border: `1px solid ${selected ? theme.line : 'transparent'}`,
        transition: 'all 120ms ease',
      }}
    >
      <div style={{
        width: 14, height: 14, borderRadius: '50%',
        border: `1.25px solid ${selected ? theme.ink : theme.muteSoft}`,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        flexShrink: 0,
      }}>
        {selected && (
          <div style={{ width: 7, height: 7, borderRadius: '50%', background: theme.ink }} />
        )}
      </div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{
          fontFamily: F_UI, fontSize: 13, fontWeight: 500, color: theme.ink,
          display: 'flex', alignItems: 'center', gap: 8,
        }}>
          {model.label}
          {model.recommended && (
            <span style={{
              fontFamily: F_MONO, fontSize: 9, letterSpacing: 1,
              color: theme.mute, textTransform: 'uppercase',
              padding: '2px 5px', borderRadius: 3,
              border: `1px solid ${theme.line}`,
            }}>Recommended</span>
          )}
        </div>
        <div style={{
          fontFamily: F_MONO, fontSize: 10.5, color: theme.mute,
          marginTop: 2, letterSpacing: 0.3,
        }}>
          {model.meta}
        </div>
      </div>
    </div>
  );
}

function SelectRow({ theme, value, hint }) {
  return (
    <div style={{
      padding: '10px 12px', borderRadius: 6,
      border: `1px solid ${theme.line}`,
      background: theme.panelSoft,
      display: 'flex', alignItems: 'center', justifyContent: 'space-between',
    }}>
      <div>
        <div style={{ fontFamily: F_UI, fontSize: 13, color: theme.ink }}>{value}</div>
        {hint && <div style={{ fontFamily: F_MONO, fontSize: 10.5, color: theme.mute, marginTop: 2 }}>{hint}</div>}
      </div>
      <Icon.Chevron size={12} />
    </div>
  );
}

function ToggleRow({ theme, label, hint, value, onChange }) {
  return (
    <div
      onClick={() => onChange(!value)}
      style={{
        padding: '10px 12px', borderRadius: 6,
        cursor: 'pointer',
        display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 12,
      }}
    >
      <div style={{ flex: 1 }}>
        <div style={{ fontFamily: F_UI, fontSize: 13, color: theme.ink }}>{label}</div>
        {hint && <div style={{ fontFamily: F_MONO, fontSize: 10.5, color: theme.mute, marginTop: 2, lineHeight: 1.4 }}>{hint}</div>}
      </div>
      <Toggle theme={theme} value={value} />
    </div>
  );
}

function Toggle({ theme, value }) {
  return (
    <div style={{
      width: 32, height: 19, borderRadius: 10,
      background: value ? theme.ink : theme.muteSoft,
      transition: 'background 180ms ease',
      position: 'relative', flexShrink: 0,
    }}>
      <div style={{
        position: 'absolute', top: 2, left: value ? 15 : 2,
        width: 15, height: 15, borderRadius: '50%',
        background: theme.panel,
        transition: 'left 180ms cubic-bezier(.4,0,.2,1)',
        boxShadow: '0 1px 2px rgba(0,0,0,0.15)',
      }} />
    </div>
  );
}

Object.assign(window, { Sidebar, IconButton, SettingsModal, formatTime, formatDuration });
