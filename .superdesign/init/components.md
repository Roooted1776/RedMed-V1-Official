# Components — Assist tap shell

There is no React/Vue component library. Shared UI is CSS classes plus markup inside one file: `tapper/index.html`. Styles live in the `<style>` block (lines 244–1858). Full stylesheet is in `theme.md`.

Framework: none (static HTML). CSS: vanilla custom properties. No Tailwind.

## Card
Identity and list surfaces. Cream `--surface`, radius `--box` (12px), soft shadow.

```css
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
```

## EmptyState (`rm-empty`)
Shown only when `html.is-unlinked` (bare /tapper/ with no `#d=`). Pill "No Patient". Does not invent medical facts.

```css
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
```

## IdentityRow (`.row`)
Label left, value right. Empty values use class `empty` and the em dash character. Unset flags stay an em dash, never the word No.

```css
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
```

## Button
Full-width. Variants: `btn-ink` (dark), `btn-call` (red gradient), `btn-sos` (dark, `.armed` turns accent), `btn-primary`, `btn-secondary`.

```css
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
```

## GpsCard
Centered coordinates, status pill (GPS OFF / ACQUIRING GPS / LIVE GPS).

```css
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
```

## SeizureStrip
Timer row on the 911 panel.

```css
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
```

## TabBar
In-flow bottom bar (not position:fixed). Three tabs: RedMed, 911, Aid. Active tab is accent with a tinted 32px icon chip. Home-indicator pill under the tabs.

```css
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
```
