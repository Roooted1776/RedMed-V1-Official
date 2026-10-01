# Extractable components

Vanilla HTML/CSS, not React. Extract only if a multi-page flow needs shared chrome. This redesign is one page with three panels.

## TabBar
- Source: `tapper/index.html` (nav.tabbar, lines 2313–2320; CSS 1720–1819)
- Category: layout
- Description: Bottom three-tab bar, RedMed · 911 · Aid, in-flow under the scrolling column
- Extractable props: activeItem (string, default: "medical") — one of medical, 911, aid
- Hardcoded: labels RedMed, 911, Aid; person / compass / med-kit SVGs; cream bar; accent active chip; home pill

## PageHelpChrome
- Source: `tapper/index.html` (`.rm-help-chrome`, `.page-help-chrome`)
- Category: layout
- Description: Right-aligned Help link; RedMed tab also has Auto/Phone/Tablet/Wide chips
- Extractable props: showViewChips (boolean, default: true on RedMed only)
- Hardcoded: Help label, href `../Document/`, chip labels

## IdentityCard
- Source: `tapper/index.html` (`.you-stack` / `.you-card`)
- Category: basic
- Description: Name and vitals rows. Empty fields render an em dash, never No
- Extractable props: none for layout extraction (values come from `#d=` at runtime)
- Hardcoded: row labels Name, Birth Date, Blood Type, Organ Donor, Pregnant, Deaf / Vision Impaired, Notes

## ListDrops
- Source: `tapper/index.html` (`.list-grid`)
- Category: basic
- Description: Allergies, Medicines, Conditions, Contacts disclosures
- Extractable props: none
- Hardcoded: titles and chevrons

Skip extracting Button, GpsCard, and Aid rows as DraftComponents. They are simple and should stay inline in the draft.
