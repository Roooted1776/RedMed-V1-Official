# RedMed Assist — design system

Product: the page a stranger opens by tapping a RedMed band.
URL: `https://redmed.live/tapper/`
File: one static `tapper/index.html`. Inline CSS. No framework, no webfont download, no login, no ads, no server round-trip for the medical card.

## Who it is for

A passerby or responder on whatever phone they have (iPhone Safari or Android Chrome), often outside, sometimes at night in the rain. They did not install an app. NFC tap opens this HTML file. The card must be readable in a few seconds.

## Job

1. Show the medical ID that is actually on the band (`#d=` fragment, decoded on the phone).
2. Let them call emergency services and read GPS.
3. Let them open short first-aid steps (Aid).

## Hard product rules (do not design these away)

- One HTML file. System font stack only. No Google fonts, no icon font, no extra network for the first paint.
- Works as a phone tap: one column, thumb-reachable bottom tabs, 44px minimum hit targets, safe-area padding, no hover-only actions.
- Tabs stay exactly three: **RedMed · 911 · Aid**. No Edit, no NFC write, no sign-in, no Accept.
- Unset medical fields render an em dash (—). Never the word "No". An empty band is "No Patient", not a fake chart.
- Logo position: the real RedMed mark (white heart + red ECG). Do not replace it with initials, an emoji, a generic cross, or an invented SVG.
- SOS stays a full-sound, full-light control labeled **SOS · Locate Me**. It is not a decoration and it is not on by default.
- Emergency number on the call button is **112** (the page's current label).
- Phone, tablet, and wide are the same column, just wider. Do not invent a dashboard sidebar.

## Current UI (reproduction baseline only)

Use this palette only when matching today's page pixel for pixel.

- Background `#fff7f7`, wash `#ffe8eb`, surface `#fff3f4`, ink `#1c1917`, muted `#78716c`, accent `#e11d48`, accent lift `#ff7289`
- Radius 12px cards, 8px chips
- Shadow `0 3px 8px rgba(0,0,0,0.045)`
- Type: `-apple-system, BlinkMacSystemFont, "SF Pro Text", "Segoe UI", sans-serif`
- Header: circle logo 72px, name 22px/700, status line, then either the empty card or label/value rows
- Bottom bar: cream, 52px tabs, active tab red with a tinted icon chip, small home pill

## Modern refresh (the only new visual language)

The user asked for a more modern look that is still a quick info card. Layout may get clearer. Information may not get longer. Do not add marketing sections, testimonials, illustrations, or a hero slogan.

Shared rules for every modern variation:

- Font: the system stack above. Nothing else.
- Accent stays RedMed red `#e11d48`. Night mode may use `#ff4d6d` for the same role so red stays visible on a dark surface. No purple, no neon, no extra brand hues.
- Ink `#1c1917` on light surfaces. On night surfaces, text `#faf7f5`, muted `#a8a29e`.
- Radius: 16px cards, 999px pills. Not 0, not 28px blobs.
- Shadow on light surfaces: `0 1px 2px rgba(28,25,23,0.06), 0 8px 24px rgba(28,25,23,0.06)`.
- Labels: 11px, weight 700, uppercase, tracking 0.08em, muted.
- Values: 17px, weight 600, ink. Blood type is the exception: 28px, weight 800.
- Screen order on RedMed, top to bottom, still one column:
  1. Small wordmark row: logo 40px (still the real mark) + "RedMed" + a quiet status
  2. Person's name, large
  3. Blood type as the loudest chip when a type is present; em dash chip when it is not
  4. Allergies as the next line, full width, because a responder looks there second
  5. The rest of the rows (birth date, medicines, conditions, donor, pregnant, deaf / vision, notes, contacts) in a single quiet card
- 911 and Aid keep the same controls and the same words. They may use the same surfaces, radius, and type as the RedMed card. Do not restyle them into a different product.
- Bottom tabs stay. Active tab uses the accent. Labels stay RedMed, 911, Aid.

### Daylight (variation A)

- Page `#f4f1ee`
- Card `#ffffff`
- Accent `#e11d48`
- Blood chip: solid `#e11d48`, white type
- Allergy line: `#fff1f2` background, `#9f1239` text, only as a container; if the list is empty the value is an em dash, not a warning

### Night roadside (variation B)

- Page `#100e0d`
- Card `#1c1917`
- Text `#faf7f5`
- Accent and blood chip `#ff4d6d` with `#1c1917` or white type, whichever keeps WCAG-ish contrast on that chip
- Same order as daylight. This is the same card in the dark, not a new layout.

## Motion

None on first paint. Buttons may scale to 0.98 on press. Honor `prefers-reduced-motion`.

## Sample content for drafts

Use a filled card so the hierarchy is visible, and keep every value obviously sample:

- Name: Jordan Hale
- Blood: O+
- Allergies: Penicillin
- Birth date: 1994-03-12
- Medicines: —
- Conditions: —
- Organ donor: Yes
- Pregnant: —
- Deaf / Vision Impaired: —
- Notes: —
- Status: Linked

Empty-state copy, if shown: pill "No Patient", heading "No Medical ID On This Page".
