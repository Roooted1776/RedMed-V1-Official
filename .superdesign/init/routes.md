# Routes — Assist

Static files. No client router. Tabs are in-page panels, not URLs.

| URL | File | Layout | What renders |
| --- | --- | --- | --- |
| `https://redmed.live/tapper/` | `tapper/index.html` | App shell + tab bar | RedMed empty state (No Patient). 911 and Aid still switch. |
| `https://redmed.live/tapper/#d=<payload>` | same file | same | Medical card decrypted in the browser from the fragment. Fragment is never sent to a server. |
| `https://redmed.live/tapper/#911` or `?tab=911` | same | same | 911 panel first |
| `https://redmed.live/tapper/#aid` or `?tab=aid` | same | same | Aid panel first |
| `?view=phone\|tablet\|wide` | same | locks column width | Device preview chrome |
| `?src=app` | same | owner preview | No SOS from a bare open; view chrome hidden |
| `tapper/emergency.html` | redirect stub | — | Not the product shell |
| `../Document/` | help docs | separate | Help · Policies link target |

Deep link rule: a hash that starts with `#d=` is a profile payload, never a tab id. Optional `&tab=911` or `&tab=aid` inside that hash can select a tab.

There is no router config file.
