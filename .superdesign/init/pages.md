# Pages — dependency trees

One file owns the UI. No local imports.

## /tapper/ (Assist shell — RedMed, 911, Aid)
Entry: `tapper/index.html`
Dependencies:
- `tapper/index.html` (markup, CSS, `#d=` paint, tabs, SOS, Aid topics)
  - `tapper/BrandLogo.svg` (header mark; PNG densities are siblings, applied after first paint)
  - `tapper/sw.js` (cache-first shell; not visual)
- `assets/BrandLogo.svg` (repo brand copy of the same mark)

Candidate `--context-file` set for this target (budget: the HTML file is ~4700 lines, so pass line ranges, not the whole file):
- `tapper/index.html:1898:1984` RedMed panel markup
- `tapper/index.html:2186:2320` 911, Aid, tab bar markup
- `tapper/index.html:244:380` tokens, page background, type
- `tapper/index.html:731:889` cards, empty state, rows
- `tapper/index.html:1103:1320` buttons, GPS, seizure
- `tapper/index.html:1720:1819` tab bar
- `.superdesign/design-system.md`
- `.superdesign/init/theme.md` token summary (do not pass the raw stylesheet twice)

## /tapper/emergency.html
Entry: `tapper/emergency.html`
Redirect stub. Not a design target.
