Run the RedMed ship gates from the repo root and report pass/fail for each:

```bash
bash scripts/sync-tapper.sh
node scripts/test-d-codec.mjs
node scripts/test-product-independence.mjs
node scripts/test-nfc-hardware.mjs
```

Follow `.cursor/skills/redmed-ship-gates/SKILL.md`. Paste real output on fail. Do not invent product policy.
