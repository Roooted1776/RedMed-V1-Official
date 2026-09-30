# _archive

Files that nothing in this repo uses. Moved here (with their original paths) so the
main folders only hold live files. Safe to delete, or move back with `git mv`.

- `index-new.html`, `site-new.css`: an unfinished landing page. It loads scripts and
  styles that do not exist, and nothing serves it.
- `owner/RedMed/Help.html`: an old redirect stub, not part of the Xcode project.
- `scripts/run.sh`, `scripts/fix-stale-redmed-xcode.sh`, `scripts/go-live-checklist.sh`,
  `scripts/test-owner-tap-quiet.mjs`: old helper scripts nothing calls. Note
  `test-owner-tap-quiet.mjs` still works but CI never ran it; move it back to `scripts/`
  if you want that check again.
