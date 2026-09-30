# _archive

Files that nothing in this repo uses. Moved here (with their original paths) so the
main folders only hold live files. Safe to delete, or move back with `git mv`.

- `index-new.html`: the marketing homepage copied onto the VPS as
  `https://redmed.live/` (`index.html` in this repo is the github.io stub, not that page).
  It must not collect an email, a password, or a code. Styles and photos for it live on the
  VPS (`assets/index-B1ncWDwK.css`, `band-hero.webp`). `site-new.css` is unused.
- `owner/RedMed/Help.html`: an old redirect stub, not part of the Xcode project.
- `scripts/run.sh`, `scripts/fix-stale-redmed-xcode.sh`, `scripts/go-live-checklist.sh`,
  `scripts/test-owner-tap-quiet.mjs`: old helper scripts nothing calls. Note
  `test-owner-tap-quiet.mjs` still works but CI never ran it; move it back to `scripts/`
  if you want that check again.
- `docs/release/VERIFICATION-2026-09-26.md`, `docs/hardware/cold-start-audit.md`: old notes nothing links to.
