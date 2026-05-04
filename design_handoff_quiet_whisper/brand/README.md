# Quiet Whisper — Brand & Icon Assets

Open **`Quiet Whisper Brand.html`** in the project root for the full visual guide.
This README is the developer-facing summary.

## What's in this folder

```
brand/
├── app-icon.svg               # macOS app icon, squircle-masked, 1024px viewBox
├── mark-on-cream.svg          # Mark on cream (default)
├── mark-on-ink.svg            # Mark on ink (inverse)
├── glyph-ink.svg              # Glyph only, ink, transparent
├── glyph-cream.svg            # Glyph only, cream, transparent
├── glyph-mono.svg             # Glyph only, currentColor
├── menu-bar.svg               # 18px template for macOS menu bar
├── AppIcon.iconset/           # All ten PNGs Apple expects
├── social/                    # Marketing / favicon-ready PNGs
└── build-icns.sh              # Compiles the iconset into AppIcon.icns
```

All SVGs are canonical. PNGs are derived from `app-icon.svg`.

## Palette

| Token        | Hex       | Use                              |
|--------------|-----------|----------------------------------|
| Warm Cream   | `#f3ead7` | Paper · primary background       |
| Warm Ink     | `#1a120c` | Ink · primary mark               |
| Cream Shadow | `#ede2c9` | Borders, dividers, soft surfaces |

Always pair cream and ink. Never place the mark on saturated colors,
pure black, or pure white.

## Building the macOS .icns

The iconset filenames here use `-at2x` as a placeholder for Apple's
`@2x` convention (filesystem constraint). The build script renames
them before running `iconutil`. Run it from this directory:

```bash
chmod +x build-icns.sh
./build-icns.sh
# → AppIcon.icns
```

The Quiet Whisper app itself uses an Xcode asset catalog
(`QuietWhisper/QuietWhisper/Resources/Assets.xcassets/AppIcon.appiconset`)
populated from these PNGs — `.icns` is the alternate path for other
consumers (e.g. `Info.plist` `CFBundleIconFile`).

## Using the SVGs in code

```html
<!-- Favicon (modern browsers, SVG-aware) -->
<link rel="icon" type="image/svg+xml" href="brand/app-icon.svg" />
<link rel="icon" type="image/png" href="brand/social/app-icon-256.png" />

<!-- Apple touch icon (iOS adds its own mask) -->
<link rel="apple-touch-icon" href="brand/social/app-icon-512.png" />

<!-- Inline mark inheriting current text color -->
<svg><use href="brand/glyph-mono.svg#mark"/></svg>
```

## Menu-bar (template) icon

`menu-bar.svg` uses `currentColor` so macOS can auto-invert it for
light/dark menu bars. In Swift:

```swift
let img = NSImage(named: "MenuBarIcon")
img?.isTemplate = true
```

## Regenerating PNGs

PNGs were rasterized from `app-icon.svg`. To re-export after changing
the SVG, ask the assistant to re-run the rasterization step, or use any
SVG-to-PNG tool (e.g. `rsvg-convert`, `inkscape --export-type=png`).

## Don't

- Don't rotate, stretch, or recolor the mark.
- Don't apply gradients, shadows, or glow — the halo is built in.
- Don't crowd: reserve clear space equal to ¼ the mark's width on each side.
- Don't use the mark below 16px; use `menu-bar.svg` instead.
