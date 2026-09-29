# RedMed account URL

This directory is a static notice. It is not a sign-in site.

Account sync (email code, and a password if the account already has one)
lives only in the iPhone app: Help → Account Sync. This page does not
collect an email, a password, or a code, and it does not call Supabase.

- No scripts.
- No form.
- No `#d=` handling.
- Separate from `tapper/`. The emergency card stays at `/tapper/`.

## Local check

```
cd portal
python3 -m http.server 8000
```

Open `http://localhost:8000/` and confirm there is no email, password, or
code field.
