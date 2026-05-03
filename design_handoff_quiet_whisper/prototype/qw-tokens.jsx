// Theme tokens + icons + seed data for Quiet Whisper

// ──────────────────────────────────────────────
// Themes — Paper (light + dark).
// Dark mode is a warm near-black, NOT pure black, to keep the paper feel.
// ──────────────────────────────────────────────
const lightTheme = {
  mode: 'light',
  bg: '#f6f4ef',
  panel: '#ffffff',
  panelSoft: '#faf8f3',
  sidebar: '#efece5',
  ink: '#1a1815',
  inkSoft: '#3a352d',
  mute: '#8a857b',
  muteSoft: '#b5b0a4',
  line: 'rgba(26,24,21,0.08)',
  lineSoft: 'rgba(26,24,21,0.04)',
  hover: 'rgba(26,24,21,0.04)',
  active: 'rgba(26,24,21,0.08)',
  selected: 'rgba(26,24,21,0.07)',
  recordBg: '#1a1815',
  recordFg: '#f6f4ef',
  dotIdle: 'rgba(26,24,21,0.18)',
  dotActive: 'rgba(26,24,21,0.78)',
  danger: '#a8443a',
  shadow: '0 1px 2px rgba(26,24,21,0.04), 0 8px 32px rgba(26,24,21,0.06)',
  traffic: { r: '#ff6b6b', y: '#ffc145', g: '#6dd66d' },
};

const darkTheme = {
  mode: 'dark',
  bg: '#17150f',
  panel: '#1e1b15',
  panelSoft: '#1a1812',
  sidebar: '#141209',
  ink: '#f0ebe0',
  inkSoft: '#c9c3b6',
  mute: '#7a756b',
  muteSoft: '#5a554c',
  line: 'rgba(240,235,224,0.08)',
  lineSoft: 'rgba(240,235,224,0.04)',
  hover: 'rgba(240,235,224,0.04)',
  active: 'rgba(240,235,224,0.08)',
  selected: 'rgba(240,235,224,0.07)',
  recordBg: '#f0ebe0',
  recordFg: '#17150f',
  dotIdle: 'rgba(240,235,224,0.18)',
  dotActive: 'rgba(240,235,224,0.82)',
  danger: '#d87268',
  shadow: '0 1px 2px rgba(0,0,0,0.2), 0 8px 32px rgba(0,0,0,0.4)',
  traffic: { r: '#ff6b6b', y: '#ffc145', g: '#6dd66d' },
};

// Fonts
const F_SERIF = '"Fraunces", "Iowan Old Style", Georgia, serif';
const F_UI = '"Inter", -apple-system, BlinkMacSystemFont, "SF Pro Text", system-ui, sans-serif';
const F_MONO = '"JetBrains Mono", ui-monospace, Menlo, monospace';

// ──────────────────────────────────────────────
// Icons — minimal stroke SVG, theme colors passed via currentColor
// ──────────────────────────────────────────────
const Icon = {
  Sidebar: ({ size = 16 }) => (
    <svg width={size} height={size} viewBox="0 0 16 16" fill="none">
      <rect x="2" y="3" width="12" height="10" rx="2" stroke="currentColor" strokeWidth="1.25" />
      <line x1="6.5" y1="3.5" x2="6.5" y2="12.5" stroke="currentColor" strokeWidth="1.25" />
    </svg>
  ),
  Settings: ({ size = 16 }) => (
    // Proper gear: 8 trapezoidal teeth around a circular hub, hollow center.
    <svg width={size} height={size} viewBox="0 0 16 16" fill="none">
      <path
        d="M8 1.4l1.05.5.55 1.55 1.6.3 1.15-1.15 1.05 1.05-1.15 1.15.3 1.6 1.55.55.5 1.05-.5 1.05-1.55.55-.3 1.6 1.15 1.15-1.05 1.05-1.15-1.15-1.6.3-.55 1.55L8 14.6l-1.05-.5-.55-1.55-1.6-.3-1.15 1.15-1.05-1.05 1.15-1.15-.3-1.6L1.9 9.05 1.4 8l.5-1.05 1.55-.55.3-1.6L2.6 3.65l1.05-1.05L4.8 3.75l1.6-.3.55-1.55L8 1.4Z"
        stroke="currentColor" strokeWidth="1.1" strokeLinejoin="round"
      />
      <circle cx="8" cy="8" r="2.1" stroke="currentColor" strokeWidth="1.1" />
    </svg>
  ),
  Sun: ({ size = 16 }) => (
    <svg width={size} height={size} viewBox="0 0 16 16" fill="none">
      <circle cx="8" cy="8" r="3" stroke="currentColor" strokeWidth="1.25" />
      <path d="M8 1.5v1.5M8 13v1.5M14.5 8H13M3 8H1.5M12.6 3.4l-1 1M4.4 11.6l-1 1M12.6 12.6l-1-1M4.4 4.4l-1-1" stroke="currentColor" strokeWidth="1.25" strokeLinecap="round" />
    </svg>
  ),
  Moon: ({ size = 16 }) => (
    <svg width={size} height={size} viewBox="0 0 16 16" fill="none">
      <path d="M13 9.5A5.5 5.5 0 0 1 6.5 3c0-.5.1-1 .2-1.5A6 6 0 1 0 14.5 9.3c-.5.1-1 .2-1.5.2Z" stroke="currentColor" strokeWidth="1.25" strokeLinejoin="round" />
    </svg>
  ),
  Plus: ({ size = 16 }) => (
    <svg width={size} height={size} viewBox="0 0 16 16" fill="none">
      <path d="M8 3v10M3 8h10" stroke="currentColor" strokeWidth="1.25" strokeLinecap="round" />
    </svg>
  ),
  Trash: ({ size = 14 }) => (
    <svg width={size} height={size} viewBox="0 0 16 16" fill="none">
      <path d="M3 4.5h10M6.5 4.5V3a1 1 0 0 1 1-1h1a1 1 0 0 1 1 1v1.5M4.5 4.5l.5 8a1 1 0 0 0 1 1h4a1 1 0 0 0 1-1l.5-8M7 7v4M9 7v4" stroke="currentColor" strokeWidth="1.1" strokeLinecap="round" strokeLinejoin="round"/>
    </svg>
  ),
  Copy: ({ size = 14 }) => (
    <svg width={size} height={size} viewBox="0 0 16 16" fill="none">
      <rect x="5" y="5" width="8" height="9" rx="1.5" stroke="currentColor" strokeWidth="1.1" />
      <path d="M3 11V3.5A1.5 1.5 0 0 1 4.5 2H10" stroke="currentColor" strokeWidth="1.1" strokeLinecap="round" />
    </svg>
  ),
  Close: ({ size = 14 }) => (
    <svg width={size} height={size} viewBox="0 0 16 16" fill="none">
      <path d="M4 4l8 8M12 4l-8 8" stroke="currentColor" strokeWidth="1.25" strokeLinecap="round" />
    </svg>
  ),
  Check: ({ size = 14 }) => (
    <svg width={size} height={size} viewBox="0 0 16 16" fill="none">
      <path d="M3.5 8.5l3 3 6-7" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  ),
  Chevron: ({ size = 12, dir = 'down' }) => {
    const rot = { down: 0, up: 180, left: 90, right: -90 }[dir] || 0;
    return (
      <svg width={size} height={size} viewBox="0 0 16 16" fill="none" style={{ transform: `rotate(${rot}deg)` }}>
        <path d="M4 6l4 4 4-4" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" />
      </svg>
    );
  },
};

// ──────────────────────────────────────────────
// Seed history — realistic snippets across recent dates.
// Dates are offsets from "now" so grouping (Today/Yesterday/This week/Earlier) works.
// ──────────────────────────────────────────────
const now = Date.now();
const HOUR = 3600 * 1000;
const DAY = 24 * HOUR;

const seedSnippets = [
  {
    id: 'n1',
    title: 'Onboarding flow rethink',
    text: "I've been thinking about the onboarding. The current flow asks for too much up front — name, workspace, team size — before the user has seen anything. What if we inverted it? Let them into the product with a throwaway workspace, and only ask for the heavy stuff when they try to invite someone or save permanently.",
    createdAt: now - 2 * HOUR,
    durationSec: 28,
  },
  {
    id: 'n2',
    title: 'Groceries for the week',
    text: "Grocery list for the week. Milk, eggs, sourdough from the bakery on 4th, two lemons, a bunch of parsley, olive oil because we're almost out, and whatever looks good at the fish counter — probably salmon or cod. Also grab coffee beans, the medium roast from the usual place.",
    createdAt: now - 6 * HOUR,
    durationSec: 22,
  },
  {
    id: 'n3',
    title: 'Standup notes',
    text: "Yesterday I finished the migration script and got it reviewed. Today I'm going to run it against staging and start on the audit log rework. Blocker: still waiting on the infra team to spin up the new Redis cluster — I'll ping them again after standup.",
    createdAt: now - 1 * DAY - 3 * HOUR,
    durationSec: 18,
  },
  {
    id: 'n4',
    title: 'Letter to Dad',
    text: "Hey Dad, just wanted to check in. The garden's starting to come back — the rosemary survived the winter, which I did not expect. How's Mom doing with the new physio? I'm thinking of driving up the weekend of the 18th, does that still work for you both?",
    createdAt: now - 1 * DAY - 8 * HOUR,
    durationSec: 35,
  },
  {
    id: 'n5',
    title: 'Q3 retro thoughts',
    text: "For the retro: we shipped the two big rocks but missed the third because we underestimated the integration work. The pairing experiment was mostly a win — people liked it on the frontend team, the backend team felt it slowed them down. We should keep it optional, not mandated.",
    createdAt: now - 3 * DAY - 4 * HOUR,
    durationSec: 42,
  },
  {
    id: 'n6',
    title: 'Book note — Oliver Burkeman',
    text: "The line that stuck with me from Four Thousand Weeks is that you never actually get on top of things — the inbox is infinite, the to-do list is infinite, and accepting that is the precondition for doing anything meaningful at all. I want to come back to this when I'm feeling frantic.",
    createdAt: now - 4 * DAY - 10 * HOUR,
    durationSec: 31,
  },
  {
    id: 'n7',
    title: 'Apartment viewing checklist',
    text: "Things to check at the apartment tomorrow: water pressure in both bathrooms, does the oven actually work, is there real phone signal in the back bedroom, what's the building noise like at 7pm, and take a photo of the fuse box.",
    createdAt: now - 6 * DAY - 2 * HOUR,
    durationSec: 24,
  },
  {
    id: 'n8',
    title: 'Pitch opening',
    text: "We think the problem with writing isn't that people don't have ideas — it's that the ideas arrive when you can't write them down. In the shower, on a walk, driving. Quiet Whisper is built for that moment: press one button, say the thing, and it's waiting for you when you sit down.",
    createdAt: now - 9 * DAY - 5 * HOUR,
    durationSec: 38,
  },
  {
    id: 'n9',
    title: 'Birthday plans',
    text: "For Mia's birthday, I'm thinking dinner somewhere quiet — not the usual group thing. Maybe that Italian place on Bleecker she mentioned. Need to book at least a week out. Gift: she's been reading a lot of poetry lately, I'll get her the new Ocean Vuong collection.",
    createdAt: now - 14 * DAY,
    durationSec: 19,
  },
];

Object.assign(window, {
  lightTheme, darkTheme, F_SERIF, F_UI, F_MONO, Icon, seedSnippets,
});
