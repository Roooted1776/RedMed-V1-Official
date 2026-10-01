---
name: redmed-ship-gates
description: >-
  Before claiming a RedMed merge is ready, a PR is green, or Assist/Owner
  ship gates passed. Run the four local gates and report pass/fail.
---

# RedMed ship gates

Do not claim merge-ready until these pass from the repo root
(`/Users/claude/RedMed Official`):

```bash
bash scripts/sync-tapper.sh
node scripts/test-d-codec.mjs
node scripts/test-product-independence.mjs
node scripts/test-nfc-hardware.mjs
```

## Rules
- Run all four before merge claims. Paste real command output on fail.
- `sync-tapper` keeps Assist shell / CACHE lockstep honest.
- `test-d-codec` + `test-product-independence` guard Assist `#d=` and the product wall.
- `test-nfc-hardware` guards NTAG216 / no-lock / CoreNFC contract (51 checks).
- Do not invent extra product policy here — see `AGENTS.md` and `.cursor/rules/`.
