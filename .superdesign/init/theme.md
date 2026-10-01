# Theme — Assist tap shell (`tapper/index.html`)

Single static HTML file. No Tailwind, no CSS modules, no component library.
All tokens and styles are inline in `tapper/index.html` `<style>` (lines 244–1858).

## Part 1 — Compact token summary

### Color
| Token | Value | Role |
| --- | --- | --- |
| `--accent` | `#e11d48` | Brand red. Links, active tab, call emphasis |
| `--accent-soft` | `#ff7289` | Lifted red |
| `--bg` | `#fff7f7` | Page cream |
| `--wash` | `#ffe8eb` | Top radial wash |
| `--dark` | `#1c1917` | Ink |
| `--muted` | `#78716c` | Secondary labels, inactive tabs |
| `--divider` | `rgba(28,25,23,0.08)` | Row rules |
| `--tab-off` | `#78716c` | Inactive tab |
| `--surface` | `#fff3f4` | Cards, notes (cream-lift, not pure white) |
| `--shadow` | `0 3px 8px rgba(0,0,0,0.045)` | Card shadow |
| `--shadow-accent` | `0 6px 16px rgba(225,29,72,0.22)` | Accent buttons |

Logo mark: white heart + `#e1242b` ECG stroke. File `tapper/BrandLogo.svg`. CSS circle-crops it.

### Type
- Family: `-apple-system, BlinkMacSystemFont, "SF Pro Text", "SF Pro Display", "Segoe UI", sans-serif`
- No webfonts. Offline / first-paint constraint.
- `--fs-name` 22px (max 22 phone / 30 wide), weight 700, tracking -0.5px
- `--fs-row` 14px, `--fs-title` 16px, `--fs-body` 14px, `--fs-btn` 16px
- Fluid via `clamp` + container query units (`cqi`)

### Space, radius, elevation
- `--box` 12px (phone lock 10px), `--chip` 8px
- `--page-pad-x` clamp(16px, 4.2vw, 28px)
- `--page-max` 480 phone / 720 tablet / 960 wide
- `--logo` 72 / 96 / 108
- `--tabbar-h` 69.5px
- Safe areas: `--safe-t/r/b/l` from `env(safe-area-inset-*)`
- Shadow is very soft (4.5% black)

### Breakpoints
- Phone: short side < 500, or `html[data-device="phone"]`. Landscape phones stay phone.
- Tablet: width ≥ 768 and height ≥ 500, or data-device=tablet. `--page-max` 720
- Wide: width ≥ 1024 and height ≥ 500, or data-device=wide. `--page-max` 960
- View lock: Auto / Phone / Tablet / Wide chrome on the RedMed tab only

### Motion
- Almost none. `:active` opacity 0.7 on help links.
- SOS light overlay exists only while the alarm is armed (full light). Not a decorative animation.
- First paint must show the active panel immediately (no opacity:0 intro).

## Part 2 — Raw `:root` and full stylesheet

```css
<style>
  :root {
    --accent: #e11d48; /* Color.redmedAccent */
    --accent-soft: #ff7289; /* Color.redmedAccentLift */
    --bg: #fff7f7; /* Color.redmedBg */
    --wash: #ffe8eb; /* Color.redmedWash */
    --dark: #1c1917; /* Color.redmedDark */
    --muted: #78716c; /* Color.redmedMuted */
    --divider: rgba(28,25,23,0.08);
    --tab-off: #78716c; /* same as --muted / Color.redmedMuted */
    /* Cream-lift — same Color.redmedSurface; not pure white on --bg. */
    --surface: #fff3f4;
    --box: 12px; /* RedMedChrome.boxRadius */
    --chip: 8px; /* RedMedChrome.chipRadius */
    --logo: 72px;
    /* Owner redmedBox: black ~4.5% opacity, y 3, radius 8 — not rose-lifted. */
    --shadow: 0 3px 8px rgba(0,0,0,0.045);
    --shadow-accent: 0 6px 16px rgba(225,29,72,0.22);
    /* Fluid shell — phone → tablet → wide (iPad / landscape). */
    --page-max: 480px;
    --page-pad-x: clamp(16px, 4.2vw, 28px);
    --tabbar-h: 69.5px; /* matches ContentView content inset */
    --fs-name: 22px; /* hero under logo — RED-9 / Main.dc */
    --fs-row: 14px; /* YOU rows + lists — matches Theme CardRow */
    --fs-title: 16px;
    --fs-body: 14px;
    --fs-btn: 16px;
    --fs-name-max: 22px;
    --fs-row-max: 15px;
    --fs-title-max: 17px;
    --fs-body-max: 16px;
    --fs-btn-max: 18px;
    --safe-t: env(safe-area-inset-top, 0px);
    --safe-r: env(safe-area-inset-right, 0px);
    --safe-b: env(safe-area-inset-bottom, 0px);
    --safe-l: env(safe-area-inset-left, 0px);
  }
  /* No-JS fallback. Auto JS stamps html[data-device] from short-side aspect.
     Gate tablet/wide on min-height: 500px so landscape phones (844×390)
     stay the phone layout — width-only min-width would promote them. */
  @media (min-width: 600px) and (min-height: 500px) {
    :root { --page-max: 560px; --logo: 80px; --tabbar-h: 69.5px; }
  }
  @media (min-width: 768px) and (min-height: 500px) {
    :root {
      --page-max: 720px;
      --logo: 96px;
      --tabbar-h: 69.5px;
      --box: 12px;
      --page-pad-x: clamp(20px, 3.6vw, 32px);
      --fs-name-max: 28px;
      --fs-row-max: 17px;
      --fs-title-max: 19px;
      --fs-body-max: 17px;
      --fs-btn-max: 20px;
    }
  }
  @media (min-width: 1024px) and (min-height: 500px) {
    :root {
      --page-max: 960px;
      --logo: 108px;
      --page-pad-x: clamp(24px, 3.2vw, 36px);
      --fs-name-max: 30px;
      --fs-row-max: 18px;
      --fs-title-max: 20px;
      --fs-body-max: 18px;
      --fs-btn-max: 21px;
    }
  }
  @media (min-width: 900px) and (min-height: 500px) and (orientation: landscape) {
    :root { --page-max: min(980px, 94vw); --logo: 108px; }
  }
  /* Locked device views (View control / ?view=). */
  html[data-device="phone"] {
    --page-max: 480px;
    --logo: 72px;
    --page-pad-x: clamp(16px, 4.2vw, 28px);
    --box: 10px;
    --fs-name-max: 22px;
    --fs-row-max: 15px;
    --fs-title-max: 17px;
    --fs-body-max: 16px;
    --fs-btn-max: 18px;
  }
  html[data-device="tablet"] {
    --page-max: 720px;
    --logo: 96px;
    --page-pad-x: clamp(20px, 3.6vw, 32px);
    --box: 12px;
    --fs-name-max: 28px;
    --fs-row-max: 17px;
    --fs-title-max: 19px;
    --fs-body-max: 17px;
    --fs-btn-max: 20px;
  }
  html[data-device="wide"] {
    --page-max: 960px;
    --logo: 108px;
    --page-pad-x: clamp(24px, 3.2vw, 36px);
    --box: 12px;
    --fs-name-max: 30px;
    --fs-row-max: 18px;
    --fs-title-max: 20px;
    --fs-body-max: 18px;
    --fs-btn-max: 21px;
  }
  * { box-sizing: border-box; -webkit-tap-highlight-color: transparent; }
  html {
    /* Locked viewport — `.app` scrolls; tabbar stays in-flow (not position:fixed). */
    height: 100%;
    max-height: 100%;
    -webkit-text-size-adjust: 100%;
    text-size-adjust: 100%;
    scrollbar-gutter: stable;
    /* Same cream as Color.redmedBg / LaunchBackground — no system white overscroll. */
    background: var(--bg);
  }
  html, body { min-height: 100%; }
  body {
    margin: 0;
    font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", "SF Pro Display", "Segoe UI", sans-serif;
    /* Cream + wash — matches RedMedPageBackground. */
    background:
      radial-gradient(120% 60% at 50% -10%, var(--wash) 0%, transparent 58%),
      var(--bg);
    color: var(--dark);
    /* Flex shell: scroll `.app`, tabbar in-flow. Avoids position:fixed + dual-scroll
       eating RedMed · 911 · Aid taps (WKWebView Preview and mobile Safari). */
    height: 100%;
    max-height: 100%;
    min-height: 100vh;
    min-height: 100dvh;
    padding: var(--safe-t) var(--safe-r) 0 var(--safe-l);
    overflow: hidden;
    touch-action: manipulation;
    position: relative;
    display: flex;
    flex-direction: column;
  }
  .skip-link {
    position: absolute;
    left: 12px;
    top: -48px;
    z-index: 100;
    background: var(--accent);
    color: #fff;
    font-weight: 700;
    font-size: 14px;
    padding: 8px 12px;
    border-radius: 8px;
  }
  .skip-link:focus,
  .skip-link:focus-visible {
    top: calc(10px + var(--safe-t));
    outline: 2px solid var(--dark);
    outline-offset: 2px;
  }
  .app {
    width: 100%;
    max-width: var(--page-max);
    margin: 0 auto;
    flex: 1 1 auto;
    min-height: 0;
    overflow-x: hidden;
    overflow-y: auto;
    -webkit-overflow-scrolling: touch;
    overscroll-behavior: contain;
  }
  /* Responsive scrollbar (desktop / Mac Catalyst; iOS uses UIScrollView indicators). */
  * {
    scrollbar-width: thin;
    scrollbar-color: rgba(28, 25, 23, 0.28) transparent;
  }
  ::-webkit-scrollbar {
    width: clamp(6px, 1.2vw, 10px);
    height: clamp(6px, 1.2vw, 10px);
  }
  ::-webkit-scrollbar-thumb {
    background: rgba(28, 25, 23, 0.28);
    border-radius: 999px;
  }
  ::-webkit-scrollbar-track {
    background: transparent;
  }
  a { color: var(--accent); text-decoration: none; }
  .panel { display: none; padding: 10px 0 28px; container-type: inline-size; }
  /* Type tracks the card/section (cqi), not a giant vw on the whole page. */
  .card, .list-grid, .rm-empty, .gps-card, .info, .seizure-strip,
  details.aid, .aid-topic, .aid-sec-card, .aid-topic-sheet, .tabbar {
    container-type: inline-size;
  }
  .panel, .card, .list-grid, .rm-empty {
    --fs-name: clamp(18px, 6.2cqi, var(--fs-name-max));
    --fs-row: clamp(12px, 4.05cqi, var(--fs-row-max));
    --fs-title: clamp(14px, 4.6cqi, var(--fs-title-max));
    --fs-body: clamp(13px, 3.9cqi, var(--fs-body-max));
    --fs-btn: clamp(14px, 4.8cqi, var(--fs-btn-max));
  }
  /* First paint stays visible — opacity:0 here read as a long white flash on load. */
  .panel.active { display: block; }

  /* —— RedMed tab (My ID look) —— */
  .rm-header {
    /* Owner chrome row top 16 + RedMedUserHeader top 2. */
    padding: 16px var(--page-pad-x) 8px;
  }
  /* Passerby Help — PageHelpChrome / ChromeTextAction (18px regular accent).
     Hidden in app-embed and Preview/Scan (native Help owns that path;
     ../Document/ is dead under file:// staging). */
  .rm-help-chrome {
    display: flex;
    justify-content: flex-end;
    align-items: center;
    gap: 10px;
    margin: 0 0 8px;
    min-height: 44px;
    flex-wrap: wrap;
  }
  .rm-help-chrome a {
    font-size: 18px;
    font-weight: 400;
    color: var(--accent);
    text-decoration: none;
    padding: 6px 2px;
    letter-spacing: -0.1px;
    -webkit-tap-highlight-color: transparent;
  }
  /* 911 / Aid — same PageHelpChrome metrics as EmergencyView / AidView. */
  .page-help-chrome {
    display: flex;
    justify-content: flex-end;
    align-items: center;
    min-height: 44px;
    padding: 16px var(--page-pad-x) 8px;
    box-sizing: border-box;
  }
  .page-help-chrome a {
    font-size: 18px;
    font-weight: 400;
    color: var(--accent);
    text-decoration: none;
    padding: 6px 2px;
    -webkit-tap-highlight-color: transparent;
  }
  .page-help-chrome a:active { opacity: 0.7; }
  .page-help-chrome a:focus-visible {
    outline: 2px solid var(--accent);
    outline-offset: 2px;
    border-radius: 4px;
  }
  html.app-embed .page-help-chrome,
  html.app-preview .page-help-chrome,
  body.app-embed .page-help-chrome,
  body.app-preview .page-help-chrome { display: none !important; }
  /* Phone / tablet / wide — passerby only (hidden in app embed / preview). */
  .rm-view-chrome {
    display: none;
    align-items: center;
    gap: 2px;
    margin-right: auto;
    padding: 2px;
    border-radius: 8px;
    background: rgba(28,25,23,0.06);
  }
  html[data-view-chrome="1"] .rm-view-chrome {
    display: inline-flex;
  }
  html.app-embed .rm-view-chrome,
  html.app-preview .rm-view-chrome,
  body.app-embed .rm-view-chrome,
  body.app-preview .rm-view-chrome {
    display: none !important;
  }
  .rm-view-chrome button {
    appearance: none;
    border: 0;
    margin: 0;
    padding: 5px 9px;
    border-radius: 6px;
    background: transparent;
    color: var(--muted);
    font: inherit;
    font-size: 12px;
    font-weight: 600;
    letter-spacing: -0.1px;
    cursor: pointer;
    -webkit-tap-highlight-color: transparent;
  }
  .rm-view-chrome button[aria-pressed="true"] {
    background: #fff;
    color: var(--dark);
    box-shadow: 0 1px 2px rgba(28,25,23,0.1);
  }
  /* Auto mode: mark the detected Phone / Tablet / Wide pick clearly. */
  .rm-view-chrome button[aria-current="true"]:not([aria-pressed="true"]) {
    color: var(--accent);
    font-weight: 700;
    box-shadow: inset 0 0 0 1.5px rgba(225,29,72,0.45);
    background: rgba(225,29,72,0.06);
  }
  .rm-view-chrome button:focus-visible {
    outline: 2px solid var(--accent);
    outline-offset: 1px;
  }
  .rm-help-chrome a:active { opacity: 0.7; }
  .rm-help-chrome a:focus-visible {
    outline: 2px solid var(--accent);
    outline-offset: 2px;
    border-radius: 4px;
  }
  html.app-embed .rm-help-chrome,
  html.app-preview .rm-help-chrome,
  body.app-embed .rm-help-chrome,
  body.app-preview .rm-help-chrome { display: none !important; }
  .rm-note {
    font-size: clamp(12px, 3.4cqi, 13px);
    font-weight: 600;
    color: var(--muted);
    line-height: 1.35;
    letter-spacing: 0.1px;
    margin: 0 auto 10px;
    max-width: min(360px, 100%);
    text-align: center;
    padding: 10px 14px;
    background: var(--surface);
    border: none;
    border-radius: var(--box);
    box-shadow: var(--shadow);
  }
  /* Filled band / named card — status note is empty-state only. */
  .rm-note.is-filled { display: none; }
  /* In-app RedMed tab embeds this shell — hide passerby tab chrome (native tabs own 911/Aid/NFC).
     Owner embed only: native boot sets `html.app-embed` before first paint; body class
     mirrors it. Preview/Scan (?src=app) must NOT get app-embed — HTML RedMed · 911 · Aid stay.
     Native Help · Edit chrome sits *above* the WKWebView (sibling), so no top inset here. */
  html.app-embed body,
  body.app-embed {
    padding-top: var(--safe-t);
    padding-bottom: var(--safe-b);
  }
  html.app-embed .tabbar,
  body.app-embed .tabbar { display: none !important; }
  html.app-embed #panel-911,
  html.app-embed #panel-aid,
  body.app-embed #panel-911,
  body.app-embed #panel-aid { display: none !important; }
  html.app-embed,
  html.app-embed body,
  body.app-embed {
    height: auto;
    overflow-x: hidden;
    /* WKWebView owns scroll in owner embed — dual-scroll ate YOU-card taps. */
    overflow-y: visible;
    -webkit-overflow-scrolling: touch;
  }
  html.app-embed #panel-medical,
  body.app-embed #panel-medical {
    display: flex !important;
    flex-direction: column;
    min-height: calc(100vh - var(--safe-t) - var(--safe-b));
    min-height: calc(100dvh - var(--safe-t) - var(--safe-b));
  }
  /* html.app-preview: Swift Preview/Scan boot. Layout is the default flex
     shell; native Back chrome is a sibling above the WKWebView (same as
     RedMed Help·Edit). Class pairs with scrollView.isScrollEnabled = false. */
  html.app-preview body,
  body.app-preview {
    padding-top: 0;
  }
  /* Owner embed: no status note / BrandWordmark above the medical card. */
  html.app-embed .rm-note,
  body.app-embed .rm-note {
    display: none;
  }
  .rm-note a {
    color: inherit;
    font-weight: inherit;
    text-decoration: none;
    pointer-events: none;
  }
  .rm-title-row {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 2px 0 4px;
  }
  .rm-logo {
    /* Scales with device view — SVG stays sharp; PNG srcset covers densities. */
    width: var(--logo);
    height: var(--logo);
    border-radius: 50%;
    overflow: hidden;
    border: none;
    /* Accent ring — thin white keyline + accent hairline under the existing
       drop shadow, borrowed from the marketing shell's plate imagery. */
    box-shadow: 0 0 0 2px rgba(255,247,247,0.9), 0 0 0 3px rgba(225,29,72,0.28), 0 3px 10px rgba(225,29,72,0.18);
    flex-shrink: 0;
    display: block;
    object-fit: cover;
    background: transparent;
    opacity: 1;
    image-rendering: auto;
  }
  /* src is applied after profile paint (resolveLogo). Hide the empty box. */
  .rm-logo:not([src]) { visibility: hidden; }
  .rm-name {
    font-size: var(--fs-name);
    font-weight: 700;
    letter-spacing: -0.5px;
    margin: 0;
    line-height: 1.15;
    color: var(--dark); /* same ink as YOU rows / Color.redmedDark (#1c1917) */
    overflow-wrap: anywhere;
    word-break: break-word;
  }
  /* Linked / Not linked row under the name. */
  .rm-meta {
    display: flex;
    flex-wrap: wrap;
    align-items: baseline;
    gap: 2px 0;
    margin: 6px 0 0;
  }
  .rm-status {
    font-size: clamp(11px, 3.0cqi, 12px);
    font-weight: 700;
    letter-spacing: 0.5px;
    text-transform: uppercase;
    color: var(--muted); /* Owner Band Not Checked — muted until linked */
    margin: 0;
  }
  .rm-status.linked {
    color: var(--accent);
  }
  /* Owner RedMed embed only — status opens native NFC tab (Write / Scan). */
  html.app-embed .rm-status.rm-status-link,
  body.app-embed .rm-status.rm-status-link {
    display: inline-flex;
    align-items: center;
    gap: 2px;
    min-height: 28px;
    margin: 0;
    padding: 2px 0;
    cursor: pointer;
    text-decoration: none;
    -webkit-tap-highlight-color: transparent;
    transition: opacity 0.14s ease;
  }
  html.app-embed .rm-status.rm-status-link:not(.linked),
  body.app-embed .rm-status.rm-status-link:not(.linked) {
    color: var(--accent);
  }
  html.app-embed .rm-status.rm-status-link::after,
  body.app-embed .rm-status.rm-status-link::after {
    content: '›';
    font-size: 15px;
    font-weight: 700;
    letter-spacing: 0;
    text-transform: none;
    line-height: 1;
    margin-left: 1px;
    opacity: 0.85;
  }
  html.app-embed .rm-status.rm-status-link:active,
  body.app-embed .rm-status.rm-status-link:active {
    opacity: 0.72;
  }
  html.app-embed .rm-status.rm-status-link:focus-visible,
  body.app-embed .rm-status.rm-status-link:focus-visible {
    outline: 2px solid var(--accent);
    outline-offset: 3px;
    border-radius: 4px;
  }
  @media (prefers-reduced-motion: reduce) {
    html.app-embed .rm-status.rm-status-link,
    body.app-embed .rm-status.rm-status-link { transition: none; }
  }
  /* Owner embed: native RedMedUserHeader is the YOU-card mark (logo + name +
     Linked) plus Edit. Hide the HTML twin so the card is not double-headed. */
  html.app-embed .rm-header,
  body.app-embed .rm-header {
    display: none !important;
  }
  html.app-embed .card.you-card,
  body.app-embed .card.you-card {
    margin-top: 4px;
  }
  .card {
    margin: 0 var(--page-pad-x);
    background: var(--surface);
    border: none;
    border-radius: var(--box);
    overflow: hidden;
    box-shadow: var(--shadow);
  }
  .card.you-card {
    margin-top: 6px;
    position: relative;
    z-index: 1;
    pointer-events: auto;
    /* Vital-glow lift — accent-tinted shadow layered under the neutral .card
       shadow, borrowed from the marketing shell's card treatment. Visual
       only; no layout change. */
    box-shadow: var(--shadow), 0 10px 28px rgba(225,29,72,0.10);
  }
  /* Owner YOU card — dual redmedSurface cards (identity rows + list drops). */
  .you-stack {
    display: flex;
    flex-direction: column;
    gap: 16px;
    margin: 4px var(--page-pad-x) 28px;
    container-type: inline-size;
    container-name: you-card;
  }
  /* Wide YOU — keep dual-card stack; slight type lift only (Owner is single column). */
  @container you-card (min-width: 560px) {
    .you-stack .row .k,
    .you-stack .row .v,
    .you-stack .list-drop-title {
      font-size: max(var(--fs-row), 14px);
    }
  }
  .you-stack .card.you-card,
  .you-stack .list-grid {
    margin: 0;
    width: 100%;
    max-width: 100%;
    background: var(--surface);
    border-radius: var(--box);
    overflow: hidden;
    box-shadow: var(--shadow);
    border: none;
  }
  .you-stack .list-grid {
    display: flex;
    flex-direction: column;
    gap: 0;
  }
  details.list-drop:not(.is-empty) .list-drop-title {
    font-weight: 600;
    color: var(--dark);
  }
  details.list-drop:not(.is-empty) .list-drop-count:not(.empty) {
    font-size: 12px;
    font-weight: 700;
    color: var(--muted);
  }
  .contact-block a.cp {
    font-weight: 600;
    padding: 0;
    margin: 0;
    border-radius: 0;
    background: transparent;
  }

  .rm-empty {
    display: none;
    margin: 8px var(--page-pad-x) 0;
    padding: 18px 16px 16px;
    background: var(--surface);
    border-radius: var(--box);
    box-shadow: var(--shadow);
  }
  html.is-unlinked .rm-empty { display: block !important; }
  html.is-unlinked .you-stack { display: none !important; }
  /* Owner embed uses the native setup funnel — keep the shell quiet. */
  html.app-embed.is-unlinked .rm-empty { display: none; }
  html.is-unlinked .rm-status { color: var(--muted); }
  .rm-empty-pill {
    display: inline-block;
    font-size: 11px;
    font-weight: 700;
    letter-spacing: 0.8px;
    text-transform: uppercase;
    color: var(--accent);
    background: rgba(225,29,72,0.1);
    border-radius: var(--chip);
    padding: 4px 9px;
    margin: 0 0 10px;
  }
  .rm-empty h2 {
    margin: 0 0 8px;
    font-size: clamp(16px, 5.2cqi, 18px);
    font-weight: 700;
    letter-spacing: -0.4px;
    line-height: 1.2;
    color: var(--dark);
  }
  .rm-empty p {
    margin: 0 0 8px;
    font-size: var(--fs-row);
    font-weight: 500;
    color: var(--muted);
    line-height: 1.4;
  }
  .rm-empty p:last-child { margin-bottom: 0; }
  .rm-empty-foot {
    margin: 12px 0 0 !important;
    padding-top: 12px;
    border-top: 1px solid var(--divider);
    font-weight: 600 !important;
    color: var(--dark) !important;
  }
  .row {
    display: flex;
    justify-content: space-between;
    align-items: center;
    gap: 12px;
    padding: 11px 16px;
    border-bottom: 1px solid var(--divider);
  }
  .row[hidden] { display: none !important; }
  .row:last-child { border-bottom: none; }
  .row .k {
    font-size: var(--fs-row);
    font-weight: 500;
    color: var(--muted);
    flex-shrink: 0;
  }
  .row .v {
    flex: 1;
    font-size: var(--fs-row);
    font-weight: 500; /* Owner youRow medium */
    color: var(--dark);
    text-align: right;
    overflow-wrap: anywhere;
    word-break: break-word;
    min-width: 0;
  }
  .row .v.empty { font-weight: 500; color: rgba(28,25,23,0.4); }
  /* Owner YOU rows — plain values (no EMT glance chips). */
  .row.row-blood.has-blood .v,
  .row.row-donor.has-donor .v,
  .row.row-pregnant.has-pregnant .v,
  .row.row-deaf.has-deaf .v {
    flex: 1;
    margin-left: 0;
    font-size: var(--fs-row);
    font-weight: 500;
    color: var(--dark);
    background: transparent;
    border-radius: 0;
    padding: 0;
    text-align: right;
    line-height: inherit;
  }
  .list-item {
    padding: 11px 16px;
    border-bottom: 1px solid var(--divider);
    font-size: var(--fs-row);
    font-weight: 500;
    color: var(--dark);
    overflow-wrap: anywhere;
    word-break: break-word;
  }
  .list-item:last-child { border-bottom: none; }
  /* Allergies / Medicines / Conditions always on; Contacts hide when vacant. */
  .list-grid {
    display: flex;
    flex-direction: column;
    gap: 0;
    margin: 14px var(--page-pad-x) 0;
    background: var(--surface);
    border-radius: var(--box);
    overflow: hidden;
    box-shadow: var(--shadow);
  }
  details.list-drop {
    background: transparent;
    border: none;
    border-radius: 0;
    width: 100%;
    min-width: 0;
    overflow: hidden;
    box-shadow: none;
  }
  details.list-drop[hidden] { display: none; }
  .list-grid[hidden] { display: none; }
  /* Dividers only between visible sections (JS marks .is-last). */
  details.list-drop:not(.is-last) {
    border-bottom: 1px solid var(--divider);
  }
  details.list-drop summary {
    cursor: pointer;
    list-style: none;
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 12px;
    padding: 11px 16px; /* same as .row / CardRow */
    min-width: 0;
    -webkit-tap-highlight-color: transparent;
    transition: opacity 0.14s ease;
  }
  details.list-drop summary:active { opacity: 0.82; }
  @media (prefers-reduced-motion: reduce) {
    details.list-drop summary { transition: none; }
  }
  details.list-drop summary::-webkit-details-marker { display: none; }
  .list-drop-title {
    flex: 1;
    min-width: 0;
    font-size: var(--fs-row); /* match .row .k */
    font-weight: 500;
    color: var(--muted);
    line-height: 1.2;
    text-transform: none;
    letter-spacing: 0;
  }
  .list-drop-count {
    font-size: var(--fs-row);
    font-weight: 600;
    color: var(--dark); /* match .row .v */
    background: transparent;
    border-radius: 0;
    padding: 0;
  }
  .list-drop-count[hidden] { display: none !important; }
  .list-drop-count.empty {
    font-weight: 500;
    color: rgba(28,25,23,0.4); /* match .row .v.empty */
  }
  details.list-drop.is-empty .list-drop-chevron { display: none; }
  details.list-drop.is-empty summary { cursor: default; }
  .list-drop-chevron {
    width: 18px;
    height: 18px;
    flex-shrink: 0;
    position: relative;
    opacity: 0.85;
  }
  .list-drop-chevron::before {
    content: '';
    position: absolute;
    top: 4px;
    left: 4px;
    width: 7px;
    height: 7px;
    border-right: 2px solid var(--muted);
    border-bottom: 2px solid var(--muted);
    transform: rotate(-45deg);
  }
  details.list-drop[open] .list-drop-chevron::before {
    top: 6px;
    transform: rotate(45deg);
    border-color: var(--accent);
  }
  .list-drop-body {
    border-top: 1px solid var(--divider);
  }
  .list-drop-body:empty::after {
    content: '—';
    display: block;
    padding: 11px 16px;
    font-size: 11px;
    font-weight: 500;
    color: rgba(120,113,108,0.4);
  }
  .list-item.empty-slot {
    color: rgba(120,113,108,0.4);
  }
  .contact-block {
    padding: 11px 16px;
    border-bottom: 1px solid var(--divider);
  }
  .contact-block:last-child { border-bottom: none; }
  .contact-block .cn-row {
    display: flex;
    align-items: baseline;
    justify-content: space-between;
    gap: 8px;
  }
  .contact-block .cn {
    font-size: var(--fs-row);
    font-weight: 600;
    color: var(--dark);
    flex: 1;
    min-width: 0;
    overflow-wrap: anywhere;
    word-break: break-word;
  }
  .contact-block a.cp {
    font-size: var(--fs-row);
    font-weight: 700;
    color: var(--accent);
    text-decoration: none;
    white-space: nowrap;
    padding: 6px 10px;
    margin: -6px -4px -6px 0;
    border-radius: var(--chip);
    background: rgba(225,29,72,0.08);
    -webkit-tap-highlight-color: transparent;
  }
  .contact-block a.cp:active { opacity: 0.75; }
  .contact-block .cd {
    font-size: var(--fs-row);
    font-weight: 500;
    color: var(--muted);
    margin-top: 2px;
  }
  #panel-medical.active {
    display: flex;
    flex-direction: column;
    min-height: 100%;
    padding-bottom: 8px;
    box-sizing: border-box;
  }
  /* Quiet prayer lives on owner native Aid only — not passerby / Preview shells. */
  /* Aid column fills the scrollport so .foot-note can sit toward the bottom. */
  #panel-aid .page-pad {
    display: flex;
    flex-direction: column;
    min-height: 100%;
    box-sizing: border-box;
    padding-top: 4px; /* Owner Aid scroll top under PageHelpChrome */
    padding-bottom: 8px;
  }
  #panel-aid .foot-note {
    margin-top: auto;
    padding-top: 28px;
  }

  /* —— 911 / Find Help —— lockstep EmergencyView (top 16, stack gap 10) —— */
  .page-pad { padding: 4px var(--page-pad-x) 0; }
  #panel-911 { padding-top: 0; padding-bottom: 24px; position: relative; overflow: hidden; }
  /* Decorative ghost numeral — visual accent only, borrowed from the
     marketing shell's giant "911" treatment. aria-hidden, absolutely
     positioned behind real content; no layout impact. */
  .panel-911-ghost {
    position: absolute;
    top: -0.06em;
    right: -0.03em;
    z-index: 0;
    font-size: 46cqi;
    font-weight: 800;
    line-height: 1;
    letter-spacing: -0.04em;
    color: var(--accent);
    opacity: 0.06;
    pointer-events: none;
    user-select: none;
  }
  #panel-911 > .page-help-chrome,
  #panel-911 > .page-pad { position: relative; z-index: 1; }
  #panel-911 .page-pad {
    display: flex;
    flex-direction: column;
    gap: 10px;
    padding-top: 0; /* PageHelpChrome owns top 16 */
  }
  #panel-911 .page-pad > .btn,
  #panel-911 .page-pad > .gps-card,
  #panel-911 .page-pad > .gps-actions,
  #panel-911 .page-pad > .seizure-strip,
  #panel-911 .page-pad > .crash-dial-hint,
  #panel-911 .page-pad > .aid-stop-alarm,
  #panel-911 .page-pad > .info {
    margin: 0;
  }
  .btn {
    display: block;
    width: 100%;
    text-align: center;
    border-radius: var(--box);
    padding: 14px;
    margin: 8px 0;
    border: none;
    font-size: var(--fs-body);
    font-weight: 600;
    cursor: pointer;
    font-family: inherit;
    touch-action: manipulation;
    transition: transform 0.16s ease, opacity 0.16s ease;
  }
  .btn:active { transform: scale(0.98); opacity: 0.92; }
  .btn:focus-visible,
  .seizure-btn:focus-visible,
  .tab:focus-visible,
  .aid-stop-alarm:focus-visible,
  summary:focus-visible {
    outline: 2px solid var(--accent);
    outline-offset: 2px;
  }
  @media (prefers-reduced-motion: reduce) {
    .btn, .tab, .tab .icon-wrap { transition: none; }
    .btn:active, .tab:active { transform: none; }
  }
  .btn-primary {
    background: linear-gradient(180deg, var(--accent-soft), var(--accent));
    color: #fff;
    font-weight: 700;
    font-size: var(--fs-btn);
    padding: 16px;
    /* Gloss highlight layered onto the existing accent shadow — visual only. */
    box-shadow: var(--shadow-accent), inset 0 1px 0 rgba(255,255,255,0.35);
  }
  .btn-secondary {
    background: var(--surface);
    border: 1px solid var(--divider);
    color: var(--dark);
    box-shadow: var(--shadow);
  }
  .btn-ink {
    background: var(--dark);
    color: #fff;
    font-weight: 700;
    font-size: 13px; /* CompactFillButton */
    padding: 11px;
    border-radius: var(--box);
  }
  .btn-call {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 8px;
    background: linear-gradient(180deg, var(--accent-soft), var(--accent));
    color: #fff;
    font-weight: 700;
    font-size: 16px; /* PrimaryButton */
    padding: 15px 12px;
    border-radius: var(--box);
    /* Gloss highlight layered onto the existing accent shadow — visual only. */
    box-shadow: var(--shadow-accent), inset 0 1px 0 rgba(255,255,255,0.35);
  }
  .btn-call-ico {
    display: inline-flex;
    width: 18px;
    height: 18px;
    flex-shrink: 0;
  }
  .btn-call-ico svg { display: block; width: 18px; height: 18px; }
  .btn-sos {
    background: var(--dark);
    color: #fff;
    font-weight: 700;
    font-size: 13px; /* CompactFillButton / FindHelpSOSButton */
    padding: 11px;
    border-radius: var(--box);
  }
  .btn-sos.armed {
    background: var(--accent);
    box-shadow: var(--shadow-accent);
  }
  .crash-dial-hint {
    display: none;
    margin: 0;
    padding: 10px 12px;
    font-size: 13px;
    font-weight: 700;
    color: var(--accent);
    background: var(--surface);
    border: 1px solid var(--divider);
    border-radius: var(--box);
  }
  .crash-dial-hint.show { display: block; }
  .hint {
    font-size: 12px;
    font-weight: 500;
    color: var(--muted);
    text-align: center;
    margin: 0 0 8px;
  }
  .gps-card {
    background: var(--surface);
    border: none;
    border-radius: var(--box);
    padding: 12px;
    text-align: center;
    box-shadow: var(--shadow);
  }
  .gps-pill {
    display: inline-block;
    font-size: 9px; /* GPSCard statusTitle */
    font-weight: 700;
    letter-spacing: 1.1px;
    color: var(--accent);
    background: rgba(225,29,72,0.1);
    border-radius: var(--chip);
    padding: 3px 8px;
    margin-bottom: 0;
  }
  /* CPR Beat & Breath — lockstep TopicDetailView metronome chrome. */
  .cpr-metro {
    background: var(--surface);
    border-radius: var(--box);
    box-shadow: var(--shadow);
    padding: 20px;
    margin-bottom: 22px;
    text-align: center;
  }
  .cpr-metro-label {
    font-size: 12px;
    font-weight: 700;
    letter-spacing: 0.6px;
    color: var(--muted);
    margin: 0 0 16px;
  }
  .cpr-metro-pulse {
    width: 100px;
    height: 100px;
    margin: 0 auto;
    border-radius: 50%;
    background: var(--accent);
    color: #fff;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 32px;
    font-weight: 800;
    transform: scale(1);
    transition: transform 0.16s ease-out, background 0.16s ease-out;
    box-shadow: 0 4px 10px rgba(225, 29, 72, 0.32);
  }
  .cpr-metro-pulse.is-beat { transform: scale(1.14); }
  .cpr-metro-pulse.is-breathe { background: #fb7185; }
  .cpr-metro-phase {
    margin: 16px 0 0;
    font-size: 16px;
    font-weight: 700;
    color: var(--accent);
  }
  .cpr-metro-hint {
    margin: 8px 0 0;
    font-size: 12px;
    font-weight: 500;
    color: var(--muted);
  }
  .cpr-metro-btn {
    margin-top: 16px;
    width: 100%;
  }
  .coords {
    font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
    font-size: clamp(13px, 4.2cqi, 15px); /* GPSCard */
    font-weight: 700;
    color: var(--dark);
    overflow-wrap: anywhere;
    word-break: break-word;
  }
  .gps-acc {
    font-size: clamp(10px, 3.2cqi, 12px);
    font-weight: 600;
    color: var(--muted);
    margin-top: 4px;
  }
  .gps-card .btn { margin: 0; }
  .gps-refresh { margin-top: 0; }
  .gps-actions {
    display: flex;
    flex-direction: column;
    gap: 7px;
    margin: 0;
  }
  .gps-actions .btn {
    margin: 0;
  }
  .seizure-strip {
    display: flex;
    align-items: center;
    gap: 8px;
    background: var(--surface);
    border: none;
    border-radius: var(--box);
    padding: 10px 12px;
    min-width: 0;
    box-shadow: var(--shadow);
  }
  .seizure-label {
    font-size: clamp(10px, 3.2cqi, 12px);
    font-weight: 700;
    letter-spacing: 0.8px;
    color: var(--muted);
  }
  .seizure-time {
    font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
    font-size: clamp(15px, 4.8cqi, 17px);
    font-weight: 700;
    color: var(--dark);
    min-width: 56px;
  }
  .seizure-time.hot {
    color: var(--accent);
  }
  .seizure-hint {
    flex: 1;
    font-size: clamp(10px, 3.4cqi, 12px);
    font-weight: 600;
    color: var(--muted);
    min-width: 0;
    overflow-wrap: anywhere;
    word-break: break-word;
  }
  .seizure-hint.hot {
    color: var(--accent);
  }
  .seizure-actions {
    display: flex;
    align-items: center;
    gap: 6px;
    flex-shrink: 0;
  }
  .seizure-btn {
    border: none;
    border-radius: var(--chip);
    padding: 6px 12px;
    font-size: clamp(10px, 3.1cqi, 11px);
    font-weight: 700;
    font-family: inherit;
    cursor: pointer;
    background: var(--accent);
    color: #fff;
  }
  .seizure-btn.on {
    background: var(--surface);
    color: var(--dark);
    border: 1px solid var(--divider);
  }
  .seizure-btn-reset {
    background: var(--surface);
    color: var(--dark);
    border: 1px solid var(--divider);
  }
  .seizure-btn-reset:disabled {
    opacity: 0.45;
    cursor: default;
  }
  .info {
    background: var(--surface);
    border: none;
    border-radius: var(--box);
    padding: 12px 14px;
    box-shadow: var(--shadow);
  }
  .info-head {
    display: flex;
    align-items: center;
    gap: 8px;
    margin-bottom: 6px;
  }
  .info-icon {
    width: 30px;
    height: 30px;
    border-radius: var(--chip);
    background: rgba(225,29,72,0.1);
    color: var(--accent);
    font-size: 14px;
    font-weight: 600;
    display: flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
  }
  .info-icon svg { display: block; width: 16px; height: 16px; }
  .info h2 {
    margin: 0;
    font-size: clamp(12px, 3.8cqi, 13px); /* InfoCard title */
    font-weight: 700;
    color: var(--dark);
    min-width: 0;
    overflow-wrap: anywhere;
  }
  .info-lead {
    margin: 0;
    font-size: 12px;
    font-weight: 600;
    line-height: 1.35;
    color: var(--muted);
  }
  .info ol, .info ul {
    margin: 0;
    padding-left: 16px;
    font-size: clamp(11px, 3.5cqi, 12px); /* InfoCard body */
    font-weight: 600;
    line-height: 1.4;
    color: var(--dark);
  }
  .info ol li + li, .info ul li + li { margin-top: 6px; }
  .foot-note {
    font-size: clamp(12px, 3.2cqi, 13px);
    font-weight: 500;
    color: var(--muted);
    text-align: center;
    line-height: 1.4;
    margin: 12px 4px 0;
  }
  .survival-note {
    margin: 6px 2px 10px;
    font-size: clamp(11px, 3.1cqi, 13px);
    font-weight: 500;
    color: var(--muted);
    line-height: 1.35;
    text-align: left;
  }
  /* SOS full light — browsers cannot force system brightness; flash the
     viewport white/red so the alarm is visually maxed with the siren. */
  .sos-light-flash {
    display: none;
    position: fixed;
    inset: 0;
    z-index: 10000;
    pointer-events: none;
    background: #fff;
    mix-blend-mode: normal;
  }
  .sos-light-flash.on {
    display: block;
    animation: sos-light-pulse 0.55s ease-in-out infinite alternate;
  }
  @keyframes sos-light-pulse {
    from { background: #fff; opacity: 0.92; }
    to { background: #ffe4e9; opacity: 1; }
  }
  .aid-stop-alarm {
    display: none;
    width: 100%;
    margin-top: 10px;
    padding: 10px 12px;
    font-size: 14px;
    font-weight: 600;
    color: var(--dark);
    background: var(--bg);
    border: 1px solid var(--divider);
    border-radius: var(--box);
    text-align: left;
    cursor: pointer;
  }
  .aid-stop-alarm.show { display: block !important; }
  .aid-stop-alarm .x {
    float: right;
    color: var(--accent);
    font-weight: 700;
  }

  /* Aid — lockstep owner AidView / PaneCard heights + topic-row structure. */
  #panel-aid { padding-top: 0; padding-bottom: 24px; }
  .aid-grid {
    display: flex;
    flex-direction: column;
    gap: 8px;
    margin-top: 0;
  }
  details.aid {
    background: var(--surface);
    border: none;
    border-radius: var(--box);
    padding: 0;
    width: 100%;
    min-width: 0;
    box-shadow: var(--shadow);
    overflow: hidden;
  }
  details.aid[open] {
    background: rgba(225,29,72,0.03);
  }
  details.aid summary {
    cursor: pointer;
    list-style: none;
    display: block;
    padding: 10px 12px; /* PaneCard H12 / V10 */
    min-width: 0;
    -webkit-tap-highlight-color: transparent;
  }
  details.aid summary .aid-summary-row {
    display: flex;
    gap: 12px;
    align-items: center;
    min-width: 0;
    width: 100%;
  }
  details.aid summary::-webkit-details-marker { display: none; }
  .aid-emoji,
  .aid-ico {
    width: 44px;
    height: 44px;
    border-radius: var(--chip);
    background: rgba(225,29,72,0.1);
    color: var(--accent);
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 22px;
    flex-shrink: 0;
  }
  .aid-ico svg { display: block; width: 20px; height: 20px; }
  details.aid[open] .aid-emoji,
  details.aid[open] .aid-ico {
    background: var(--accent);
    color: #fff;
  }
  .aid-title {
    display: block;
    font-size: clamp(14px, 4.8cqi, 16px);
    font-weight: 700;
    color: var(--accent);
    line-height: 1.2;
    flex: 1;
    min-width: 0;
    overflow-wrap: anywhere;
    word-break: break-word;
  }
  .aid-chevron {
    width: 28px;
    height: 28px;
    flex-shrink: 0;
    position: relative;
  }
  .aid-chevron::before {
    content: '';
    position: absolute;
    top: 9px;
    left: 9px;
    width: 8px;
    height: 8px;
    border-right: 2px solid var(--accent);
    border-bottom: 2px solid var(--accent);
    transform: rotate(-45deg);
    transition: transform 0.14s ease, top 0.14s ease;
  }
  details.aid[open] .aid-chevron::before {
    top: 11px;
    transform: rotate(45deg);
  }
  @media (prefers-reduced-motion: reduce) {
    .aid-chevron::before { transition: none; }
  }
  /* Topic rows — same as owner PaneCard open body.
     Trailing pad 0 + topic trailing 12 + 28px chevron = pane header ">" column. */
  .aid-topics {
    display: flex;
    flex-direction: column;
    gap: 8px;
    padding: 0 0 12px 10px;
  }
  .aid-topic {
    display: flex;
    align-items: center;
    gap: 10px;
    width: 100%;
    margin: 0;
    padding: 14px 12px 14px 14px;
    border: none;
    border-radius: var(--box);
    background: var(--surface);
    color: var(--accent);
    font-family: inherit;
    font-size: clamp(14px, 4.8cqi, 16px);
    font-weight: 600;
    text-align: left;
    cursor: pointer;
    -webkit-tap-highlight-color: transparent;
    touch-action: manipulation;
  }
  .aid-topic:active { opacity: 0.92; transform: scale(0.98); }
  .aid-topic-label {
    flex: 1;
    min-width: 0;
    overflow-wrap: anywhere;
    word-break: break-word;
  }
  .aid-topic-chevron {
    width: 28px;
    height: 28px;
    flex-shrink: 0;
    position: relative;
    opacity: 0.55;
  }
  .aid-topic-chevron::before {
    content: '';
    position: absolute;
    top: 9px;
    left: 9px;
    width: 8px;
    height: 8px;
    border-right: 2px solid var(--accent);
    border-bottom: 2px solid var(--accent);
    transform: rotate(-45deg);
  }
  /* Topic detail overlay — TopicDetailView: Back + Recognize / What to do */
  .aid-topic-sheet {
    display: none;
    position: fixed;
    inset: 0;
    z-index: 40;
    background:
      radial-gradient(120% 60% at 50% -10%, var(--wash) 0%, transparent 58%),
      var(--bg);
    flex-direction: column;
    padding: var(--safe-t) var(--safe-r) var(--safe-b) var(--safe-l);
  }
  .aid-topic-sheet.open {
    display: flex !important; /* beat [hidden] while open */
  }
  .aid-topic-sheet[hidden] {
    display: none !important;
  }
  .aid-topic-sheet-bar {
    display: flex;
    align-items: center;
    padding: 2px var(--page-pad-x) 8px;
    flex-shrink: 0;
  }
  .aid-topic-back {
    border: none;
    background: transparent;
    color: var(--accent);
    font-family: inherit;
    font-size: 18px;
    font-weight: 700;
    padding: 8px 0;
    cursor: pointer;
    -webkit-tap-highlight-color: transparent;
  }
  .aid-topic-scroll {
    flex: 1 1 auto;
    min-height: 0;
    overflow-y: auto;
    -webkit-overflow-scrolling: touch;
    padding: 0 var(--page-pad-x) 32px;
  }
  .aid-sec-label {
    margin: 4px 0 6px;
    padding: 0 4px;
    font-size: clamp(12px, 3.6cqi, 13px);
    font-weight: 600;
    letter-spacing: 0.5px;
    text-transform: uppercase;
    color: var(--accent);
  }
  .aid-sec-label.spaced { margin-top: 0; }
  .aid-sec-card {
    background: var(--surface);
    border-radius: var(--box);
    box-shadow: var(--shadow);
    overflow: hidden;
    margin-bottom: 22px;
  }
  .aid-sec-card.care { margin-bottom: 24px; }
  .aid-sec-row {
    padding: 13px 16px;
    font-size: clamp(13px, 4.2cqi, 15px);
    color: var(--accent);
    line-height: 1.35;
    border-bottom: 1px solid var(--divider);
  }
  .aid-sec-row:last-child { border-bottom: none; }
  .aid-sec-row.care-row {
    display: flex;
    align-items: flex-start;
    gap: 12px;
  }
  .aid-sec-row .care-mark {
    flex-shrink: 0;
    margin-top: 4px;
    width: 14px;
    height: 10px;
    position: relative;
  }
  .aid-sec-row .care-mark::before {
    content: '';
    position: absolute;
    top: 0;
    left: 3px;
    width: 0;
    height: 0;
    border-top: 5px solid transparent;
    border-bottom: 5px solid transparent;
    border-left: 7px solid var(--accent);
  }
  .aid-sec-row .care-text {
    flex: 1;
    min-width: 0;
    overflow-wrap: anywhere;
  }
  body.aid-topic-open .tabbar { visibility: hidden; pointer-events: none; }
  body.aid-topic-open .app { visibility: hidden; }

  /* —— Tab bar (matches CustomTabBar cream; 52px hits + 10px top pad) —— */
  .tabbar {
    position: relative;
    flex-shrink: 0;
    width: 100%;
    /* Opaque page cream — same Color.redmedBg as owner CustomTabBar (not frosted white). */
    background: var(--bg);
    border: 0.5px solid var(--divider);
    border-bottom: 0;
    border-radius: 18px 18px 0 0;
    box-shadow: 0 -2px 10px rgba(28,25,23,0.05);
    display: flex;
    flex-direction: column;
    align-items: center;
    /* Owner CustomTabBar top pad 10 — same roomier chrome for tab hops. */
    padding: 10px var(--safe-r) var(--safe-b) var(--safe-l);
    z-index: 30;
  }
  .tabs {
    display: flex;
    width: 100%;
    max-width: var(--page-max);
  }
  .tab {
    flex: 1;
    border: 0;
    background: transparent;
    padding: 0;
    /* Same grid as owner TabBarItem: icon 32 + gap 2 + label 12 = 46 in 52. */
    min-height: 52px;
    height: 52px;
    box-sizing: border-box;
    color: var(--tab-off);
    font-size: 10px;
    font-weight: 500; /* TabBarItem medium / semibold when on */
    letter-spacing: -0.1px;
    cursor: pointer;
    font-family: inherit;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 2px;
    touch-action: manipulation;
    -webkit-user-select: none;
    user-select: none;
    transition: color 0.14s ease, transform 0.12s ease;
  }
  .tab:active { transform: scale(0.96); }
  .tab .icon-wrap {
    display: flex;
    align-items: center;
    justify-content: center;
    /* Square chip — lockstep with owner CustomTabBar 32×32 + chipRadius 8. */
    width: 32px;
    height: 32px;
    flex: 0 0 32px;
    border-radius: 8px;
    margin: 0;
    line-height: 0;
    transition: background 0.14s ease;
  }
  /* Match owner CustomTabBar SF Symbols (person.fill / safari.fill / cross.case.fill).
     911 SVG uses fill-rule=evenodd so the needle cutout reads as safari.fill. */
  .tab .icon-wrap svg {
    width: 20px;
    height: 20px;
    display: block;
    fill: currentColor;
    /* Optical size/center — Material paths don't share SF Symbol metrics.
       Compass fills the full viewBox; person/aid read smaller and sit low/high. */
    flex-shrink: 0;
  }
  .tab[data-tab="medical"] .icon-wrap svg { transform: translateY(-0.5px) scale(1.06); }
  .tab[data-tab="911"] .icon-wrap svg { transform: scale(0.92); }
  .tab[data-tab="aid"] .icon-wrap svg { transform: translateY(0.25px) scale(1.1); }
  .tab .tab-label {
    display: block;
    height: 12px;
    line-height: 12px;
    white-space: nowrap;
    max-width: 100%;
    overflow: hidden;
    text-overflow: ellipsis;
    text-align: center;
    font-size: 10px;
    font-weight: inherit;
  }
  .tab.active { color: var(--accent); font-weight: 600; /* TabBarItem semibold */ }
  .tab.active .icon-wrap {
    background: rgba(225,29,72,0.12);
    box-shadow: 0 3px 8px rgba(225,29,72,0.16);
  }
  .home-pill {
    width: 118px;
    height: 4px;
    border-radius: 999px;
    background: rgba(28,25,23,0.18);
    margin-top: 2px;
  }

  /* Narrow phones (SE / mini) — keep Call / SOS usable, no horizontal clip. */
  @media (max-width: 360px) {
    :root {
      --page-pad-x: 10px;
      --tabbar-h: 71.5px;
    }
    .seizure-strip { flex-wrap: wrap; }
  }

  /* Wide / iPad: emergency card stays a column that grows with --page-max. */
  @media (min-width: 1024px) {
    #panel-medical.panel.active {
      display: flex;
      flex-direction: column;
    }
    #panel-medical > .rm-header,
    #panel-medical > .rm-empty {
      grid-column: auto;
    }
    #panel-medical > .you-stack {
      width: auto;
      max-width: 100%;
    }
  }
  html[data-device="phone"] #panel-medical.panel.active,
  html[data-device="tablet"] #panel-medical.panel.active,
  html[data-device="wide"] #panel-medical.panel.active {
    display: flex;
    flex-direction: column;
  }
  html[data-device="wide"] #panel-medical > .rm-header,
  html[data-device="wide"] #panel-medical > .rm-empty {
    grid-column: auto;
  }
  html[data-device="wide"] #panel-medical > .you-stack {
    width: auto;
    max-width: 100%;
  }
```
