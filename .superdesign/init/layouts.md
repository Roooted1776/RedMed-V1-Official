# Layouts — Assist tap shell

One app shell. No sidebar. Bottom tab bar. Scroll lives in `.app`. Tab bar is a flex sibling so taps are not eaten by `position:fixed`.

Phone, tablet, and wide are the same column, wider `--page-max`. Landscape phones stay the phone layout.

## App shell + three panels + tab bar

Source: `tapper/index.html` lines 1898–2320 (decrypt script omitted; it paints the same nodes).

```html
<body>
  <a class="skip-link" href="#panel-medical" id="skipToCard">Skip To Card</a>
  <div class="app">
    <!-- RedMed — same header + YOU card as owner RedMedView (no Edit). -->
    <div class="panel active" id="panel-medical" data-panel="medical" role="tabpanel" aria-labelledby="tab-medical" aria-hidden="false">
      <div class="rm-header">
        <div class="rm-help-chrome">
          <div class="rm-view-chrome" id="rmViewChrome" role="group" aria-label="Device view">
            <button type="button" data-view="auto" aria-pressed="true">Auto</button>
            <button type="button" data-view="phone" aria-pressed="false">Phone</button>
            <button type="button" data-view="tablet" aria-pressed="false">Tablet</button>
            <button type="button" data-view="wide" aria-pressed="false">Wide</button>
          </div>
          <a href="../Document/" aria-label="Help · Policies">Help</a>
        </div>
        <p class="rm-note">Tap To Scan · No Login · No Server · No App</p>
        <div class="rm-title-row">
          <picture>
            <source type="image/svg+xml" id="rmLogoSvgSource">
            <source type="image/png"
              sizes="(min-width: 1024px) 108px, (min-width: 768px) 96px, (min-width: 600px) 80px, 72px"
              id="rmLogoPngSource">
            <img class="rm-logo" id="rmLogo" width="72" height="72" alt="RedMed" decoding="async">
          </picture>
          <div>
            <h1 class="rm-name" id="name">RedMed</h1>
            <div class="rm-meta">
              <p class="rm-status" id="statusLine">Not Linked</p>
            </div>
          </div>
        </div>
      </div>

      <!-- Visibility: html.is-unlinked only (.rm-empty { display:none } by default).
           Never put the HTML hidden attribute here — UA [hidden]!important wins
           over author CSS and blanked bare /tapper/ lookups before JS ran. -->
      <div class="rm-empty" id="rmEmpty">
        <div class="rm-empty-pill" id="rmEmptyPill">No Patient</div>
        <h2 id="rmEmptyTitle">No Medical ID On This Page</h2>
        <p id="rmEmptyBody">A written MED ID band opens the person's name, blood type, allergies, and contacts here.</p>
        <p class="rm-empty-foot">911 and Aid still work on this phone.</p>
      </div>

      <!-- Owner YOU card — dual surface cards (identity + lists). No Accept / NFC. -->
      <div class="you-stack" id="youStack">
        <div class="card you-card identity-card">
          <div class="row" id="rowNameRow"><span class="k">Name</span><span class="v" id="rowName">—</span></div>
          <div class="row" id="rowDobRow"><span class="k">Birth Date</span><span class="v empty" id="rowDob">—</span></div>
          <div class="row row-blood" id="rowBloodRow"><span class="k">Blood Type</span><span class="v empty" id="rowBlood">—</span></div>
          <div class="row row-donor" id="rowDonorRow"><span class="k">Organ Donor</span><span class="v empty" id="rowDonor">—</span></div>
          <div class="row row-pregnant" id="rowPregnantRow"><span class="k">Pregnant</span><span class="v empty" id="rowPregnant">—</span></div>
          <div class="row row-deaf" id="rowDeafRow"><span class="k">Deaf / Vision Impaired</span><span class="v empty" id="rowDeaf">—</span></div>
          <div class="row" id="rowNotesRow"><span class="k">Notes</span><span class="v empty" id="rowNotes">—</span></div>
        </div>
        <div class="list-grid" id="youLists">
          <details class="list-drop is-empty" id="dropAllergies" open>
            <summary>
              <span class="list-drop-title">Allergies <span class="list-drop-count empty" id="countAllergies">—</span></span>
              <span class="list-drop-chevron" aria-hidden="true"></span>
            </summary>
            <div class="list-drop-body" id="allergies"></div>
          </details>
          <details class="list-drop is-empty" id="dropMedications" open>
            <summary>
              <span class="list-drop-title">Medicines <span class="list-drop-count empty" id="countMedications">—</span></span>
              <span class="list-drop-chevron" aria-hidden="true"></span>
            </summary>
            <div class="list-drop-body" id="meds"></div>
          </details>
          <details class="list-drop is-empty" id="dropConditions" open>
            <summary>
              <span class="list-drop-title">Conditions <span class="list-drop-count empty" id="countConditions">—</span></span>
              <span class="list-drop-chevron" aria-hidden="true"></span>
            </summary>
            <div class="list-drop-body" id="conditions"></div>
          </details>
          <details class="list-drop" id="dropContacts" hidden>
            <summary>
              <span class="list-drop-title">Contacts <span class="list-drop-count" id="countContacts" hidden></span></span>
              <span class="list-drop-chevron" aria-hidden="true"></span>
            </summary>
            <div class="list-drop-body" id="contacts"></div>
          </details>
        </div>
      </div>



<!-- 911 panel -->
    <div class="panel" id="panel-911" data-panel="911" role="tabpanel" aria-labelledby="tab-911" aria-hidden="true">
      <span class="panel-911-ghost" aria-hidden="true">911</span>
      <div class="page-help-chrome"><a href="../Document/" aria-label="Help · Policies">Help</a></div>
      <div class="page-pad">
        <div class="gps-actions">
          <button class="btn btn-ink gps-refresh" type="button" id="refreshCoordsBtn">Refresh</button>
          <button class="btn btn-ink" type="button" id="copyCoordsBtn" aria-label="Copy GPS Coordinates">Copy Coordinates</button>
        </div>
        <div class="gps-card" role="status" aria-live="polite">
          <!-- lockstep GPSCard.statusTitle: GPS OFF / ACQUIRING GPS / LIVE GPS -->
          <div class="gps-pill" id="gpsPill">ACQUIRING GPS</div>
          <div class="coords" id="coords">–––, –––</div>
          <div class="gps-acc" id="gpsAcc">Accuracy ––</div>
        </div>
        <button class="btn btn-sos" type="button" id="sosBtn" aria-pressed="false">SOS · Locate Me</button>
        <p class="survival-note">SOS is full sound and full light so helpers can find someone on a dark rainy night after a motorist ejects from a vehicle — only when you tap SOS · Locate Me, or when collision is detected (US Crash Detection delay). Not Apple Crash Detection. Crash detect only while this page is open. Band tap does not arm SOS.</p>
        <p class="crash-dial-hint" id="crashDialHint" hidden></p>
        <button class="aid-stop-alarm" type="button" id="aidStopAlarm" hidden>Stop The Alarm <span class="x" aria-hidden="true">✕</span></button>
        <a class="btn btn-call" id="callEmergency911" href="tel:112"><span class="btn-call-ico" aria-hidden="true"><svg viewBox="0 0 24 24" width="18" height="18" focusable="false"><path fill="currentColor" d="M6.62 10.79a15.05 15.05 0 006.59 6.59l2.2-2.2a1 1 0 011.01-.24c1.12.37 2.33.57 3.58.57a1 1 0 011 1V21a1 1 0 01-1 1C10.4 22 2 13.6 2 3a1 1 0 011-1h3.5a1 1 0 011 1c0 1.25.2 2.46.57 3.58a1 1 0 01-.25 1.01l-2.2 2.2z"/></svg></span>Call <span class="emg">112</span></a>
        <div class="seizure-strip" id="seizureStrip">
          <div>
            <div class="seizure-label">SEIZURE</div>
            <div class="seizure-time" id="seizureTime" aria-live="polite">0:00</div>
          </div>
          <div class="seizure-hint" id="seizureHint">Call <span class="emg">112</span> At 5:00</div>
          <div class="seizure-actions">
            <button class="seizure-btn seizure-btn-reset" type="button" id="seizureResetBtn">Reset</button>
            <button class="seizure-btn" type="button" id="seizureBtn">Start</button>
          </div>
        </div>

        <div class="info">
          <div class="info-head">
            <div class="info-icon" aria-hidden="true"><svg viewBox="0 0 24 24" width="16" height="16" focusable="false"><path fill="currentColor" d="M10.5 4.5h3v5.5H19v3h-5.5V19h-3v-6H5v-3h5.5V4.5z"/></svg></div>
            <h2>Roadside First Response</h2>
          </div>
          <ol>
            <li>Turn on hazards. Don't move injured — unless fire or traffic danger.</li>
            <li>Check breathing. Tilt head, lift chin. If no pulse — start CPR.</li>
            <li>Press hard on bleeding. Don't lift to check. Add cloth on top.</li>
            <li>Keep them warm and still. Talk to them. Note time of injury.</li>
          </ol>
        </div>

        <div class="info">
          <div class="info-head">
            <div class="info-icon" aria-hidden="true"><svg viewBox="0 0 24 24" width="16" height="16" focusable="false"><path fill="currentColor" d="M12 2a10 10 0 100 20 10 10 0 000-20zm1 15h-2v-6h2v6zm0-8h-2V7h2v2z"/></svg></div>
            <h2>What To Tell <span class="emg">112</span></h2>
          </div>
          <ul>
            <li>Your exact location — read the GPS coordinates above.</li>
            <li>Number of people injured and visible injuries.</li>
            <li>If anyone is unconscious or not breathing.</li>
            <li>Stay on the line — let the dispatcher guide you.</li>
          </ul>
        </div>
      </div>
    </div>

<!-- Aid panel (pane list) -->
    <div class="panel" id="panel-aid" data-panel="aid" role="tabpanel" aria-labelledby="tab-aid" aria-hidden="true">
      <div class="page-help-chrome"><a href="../Document/" aria-label="Help · Policies">Help</a></div>
      <div class="page-pad">
        <!-- Pane + topic rows lockstep AidPaneCatalog / PaneCard (owner AidView). -->
        <div class="aid-grid">
          <!-- No Nearby Hospitals here: that topic posts coordinates to
               overpass-api.de. Passerby stays server-free — it lives in the
               owner app (AidView), which asks Apple Maps on-device instead. -->
          <details class="aid"><summary><span class="aid-summary-row"><span class="aid-ico" aria-hidden="true"><svg viewBox="0 0 24 24" width="20" height="20"><path fill="currentColor" d="M18.92 6.01C18.72 5.42 18.16 5 17.5 5h-11c-.66 0-1.21.42-1.42 1.01L3 12v8c0 .55.45 1 1 1h1c.55 0 1-.45 1-1v-1h12v1c0 .55.45 1 1 1h1c.55 0 1-.45 1-1v-8l-2.08-5.99zM6.5 16c-.83 0-1.5-.67-1.5-1.5S5.67 13 6.5 13s1.5.67 1.5 1.5S7.33 16 6.5 16zm11 0c-.83 0-1.5-.67-1.5-1.5s.67-1.5 1.5-1.5 1.5.67 1.5 1.5-.67 1.5-1.5 1.5zM5 11l1.5-4.5h11L19 11H5z"/></svg></span><span class="aid-title">Crash &amp; Head</span><span class="aid-chevron" aria-hidden="true"></span></span></summary>
            <div class="aid-topics">
            <button class="aid-topic" type="button" data-topic="car-crash"><span class="aid-topic-label">Car Crash</span><span class="aid-topic-chevron" aria-hidden="true"></span></button>
            <button class="aid-topic" type="button" data-topic="head-pupils"><span class="aid-topic-label">Head &amp; Pupils</span><span class="aid-topic-chevron" aria-hidden="true"></span></button>
            <button class="aid-topic" type="button" data-topic="spinal"><span class="aid-topic-label">Spinal</span><span class="aid-topic-chevron" aria-hidden="true"></span></button>
            </div>
          </details>
          <details class="aid"><summary><span class="aid-summary-row"><span class="aid-ico" aria-hidden="true"><svg viewBox="0 0 24 24" width="20" height="20"><path fill="currentColor" d="M12 2c-3.5 4.5-6 7.6-6 11a6 6 0 0012 0c0-3.4-2.5-6.5-6-11zm0 15.5A3.5 3.5 0 018.5 14c0-1.5.9-3.1 3.5-6.5 2.6 3.4 3.5 5 3.5 6.5a3.5 3.5 0 01-3.5 3.5z"/></svg></span><span class="aid-title">Bleeding</span><span class="aid-chevron" aria-hidden="true"></span></span></summary>
            <div class="aid-topics">
            <button class="aid-topic" type="button" data-topic="find-bleeding"><span class="aid-topic-label">Find Bleeding</span><span class="aid-topic-chevron" aria-hidden="true"></span></button>
            <button class="aid-topic" type="button" data-topic="bad-bleeding"><span class="aid-topic-label">Bad Bleeding</span><span class="aid-topic-chevron" aria-hidden="true"></span></button>
            <button class="aid-topic" type="button" data-topic="belt-tourniquet"><span class="aid-topic-label">Belt Tourniquet</span><span class="aid-topic-chevron" aria-hidden="true"></span></button>
            <button class="aid-topic" type="button" data-topic="gunshot-stab"><span class="aid-topic-label">Gunshot / Stab</span><span class="aid-topic-chevron" aria-hidden="true"></span></button>
            </div>
          </details>
          <details class="aid"><summary><span class="aid-summary-row"><span class="aid-ico" aria-hidden="true"><svg viewBox="0 0 24 24" width="20" height="20"><path fill="currentColor" d="M15.5 2a3.5 3.5 0 00-3.5 3.5V9h1V5.5a2.5 2.5 0 015 0V12a1 1 0 001 1h.5A3.5 3.5 0 0023 8.5 3.5 3.5 0 0019.5 5H19v-.5A3.5 3.5 0 0015.5 2zM8.5 2A3.5 3.5 0 005 5.5V5h-.5A3.5 3.5 0 001 8.5 3.5 3.5 0 004.5 12H5a1 1 0 001-1V5.5a2.5 2.5 0 015 0V9h1V5.5A3.5 3.5 0 008.5 2zM12 10v11a1 1 0 001 1h.5a3.5 3.5 0 003.5-3.5V14h-2v4.5a1.5 1.5 0 01-1.5 1.5H13v-10h-1zm-1 0H10v10h-.5A1.5 1.5 0 018 18.5V14H6v4.5A3.5 3.5 0 009.5 22H10a1 1 0 001-1V10z"/></svg></span><span class="aid-title">Not Breathing</span><span class="aid-chevron" aria-hidden="true"></span></span></summary>
            <div class="aid-topics">
            <button class="aid-topic" type="button" data-topic="cpr"><span class="aid-topic-label">CPR</span><span class="aid-topic-chevron" aria-hidden="true"></span></button>
            </div>
          </details>
          <details class="aid"><summary><span class="aid-summary-row"><span class="aid-ico" aria-hidden="true"><svg viewBox="0 0 24 24" width="20" height="20"><path fill="currentColor" d="M21 7a2 2 0 00-2-2h-2V3a1 1 0 00-1-1h-2a1 1 0 00-1 1v2H9V3a1 1 0 00-1-1H6a1 1 0 00-1 1v2H3a2 2 0 00-2 2v2a6 6 0 006 6h1v5a1 1 0 001 1h2a1 1 0 001-1v-5h1a6 6 0 006-6V7z"/></svg></span><span class="aid-title">Choking</span><span class="aid-chevron" aria-hidden="true"></span></span></summary>
            <div class="aid-topics">
            <button class="aid-topic" type="button" data-topic="choking"><span class="aid-topic-label">Choking</span><span class="aid-topic-chevron" aria-hidden="true"></span></button>
            </div>
          </details>
          <details class="aid"><summary><span class="aid-summary-row"><span class="aid-ico" aria-hidden="true"><svg viewBox="0 0 24 24" width="20" height="20"><path fill="currentColor" d="M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35zM16 9.5l-2.2 4H15l-3 5.5.2-4H11L13.5 9H16z"/></svg></span><span class="aid-title">Shock</span><span class="aid-chevron" aria-hidden="true"></span></span></summary>
            <div class="aid-topics">
            <button class="aid-topic" type="button" data-topic="shock"><span class="aid-topic-label">Shock</span><span class="aid-topic-chevron" aria-hidden="true"></span></button>
            </div>
          </details>
          <details class="aid"><summary><span class="aid-summary-row"><span class="aid-ico" aria-hidden="true"><svg viewBox="0 0 24 24" width="20" height="20"><path fill="currentColor" d="M15 13V5a3 3 0 10-6 0v8a5 5 0 106 0zm-3 6a3 3 0 01-1-5.83V5a1 1 0 112 0v8.17A3 3 0 0112 19z"/></svg></span><span class="aid-title">Burns · Cold · Heat</span><span class="aid-chevron" aria-hidden="true"></span></span></summary>
            <div class="aid-topics">
            <button class="aid-topic" type="button" data-topic="burn-care"><span class="aid-topic-label">Burn Care</span><span class="aid-topic-chevron" aria-hidden="true"></span></button>
            <button class="aid-topic" type="button" data-topic="electrical-chemical-burns"><span class="aid-topic-label">Electrical &amp; Chemical</span><span class="aid-topic-chevron" aria-hidden="true"></span></button>
            <button class="aid-topic" type="button" data-topic="cold-hypothermia"><span class="aid-topic-label">Cold (Hypothermia)</span><span class="aid-topic-chevron" aria-hidden="true"></span></button>
            <button class="aid-topic" type="button" data-topic="heat-stroke"><span class="aid-topic-label">Heat (Exhaustion &amp; Stroke)</span><span class="aid-topic-chevron" aria-hidden="true"></span></button>
            </div>
          </details>
          <details class="aid"><summary><span class="aid-summary-row"><span class="aid-ico" aria-hidden="true"><svg viewBox="0 0 24 24" width="20" height="20"><path fill="currentColor" d="M13 3a4 4 0 014 4v.1A3.5 3.5 0 0120.5 10.5a3.5 3.5 0 01-2 3.16V15a4 4 0 01-3.2 3.92A3.5 3.5 0 0113 22h-2a3.5 3.5 0 01-2.3-3.08A4 4 0 015.5 15v-1.34a3.5 3.5 0 01-2-3.16A3.5 3.5 0 017 7.1V7a4 4 0 014-4h2zm-1 2h-1a2 2 0 00-2 2v1H8a1.5 1.5 0 100 3h1v2.5A2 2 0 009.5 15h1.2l.3 1.5A1.5 1.5 0 0012.5 18H13a1.5 1.5 0 001.5-1.5l.3-1.5H16a2 2 0 001.5-1.5V12h1a1.5 1.5 0 100-3h-2V7a2 2 0 00-2-2h-1z"/></svg></span><span class="aid-title">Seizure</span><span class="aid-chevron" aria-hidden="true"></span></span></summary>
            <div class="aid-topics">
            <button class="aid-topic" type="button" data-topic="seizure"><span class="aid-topic-label">Seizure</span><span class="aid-topic-chevron" aria-hidden="true"></span></button>
            </div>
          </details>
        </div>

        <p class="foot-note">First-aid reference only. Not medical advice and not a substitute for emergency dispatch. Call emergency services and follow their instructions.</p>
        <!-- lockstep AppConfig.Satellite.localOnlyLine (owner AidView) -->
        <p class="foot-note">Local only once tap — no RedMed servers. No Bluetooth · passive HF NFC. Call uses system tel: only (no profile, no GPS on the call). Nearby hospitals is app-only and asks Apple Maps on this phone. A band tap in a browser shows first-aid tutorials built into the page and reaches no server.</p>
      </div>
    </div>
  </div>

  <div class="aid-topic-sheet" id="aidTopicSheet" hidden aria-hidden="true">
    <div class="aid-topic-sheet-bar">
      <button type="button" class="aid-topic-back" id="aidTopicBack">Back</button>
    </div>
    <div class="aid-topic-scroll" id="aidTopicScroll"></div>
  </div>

  <nav class="tabbar" aria-label="RedMed">
    <div class="tabs" role="tablist" aria-label="Pages">
      <button class="tab active" type="button" role="tab" id="tab-medical" data-tab="medical" aria-selected="true" aria-controls="panel-medical" tabindex="0"><div class="icon-wrap" aria-hidden="true"><svg viewBox="0 0 24 24" focusable="false"><path d="M12 12c2.76 0 5-2.24 5-5s-2.24-5-5-5-5 2.24-5 5 2.24 5 5 5zm0 2c-3.33 0-10 1.67-10 5v1.5c0 .83.67 1.5 1.5 1.5h17c.83 0 1.5-.67 1.5-1.5V19c0-3.33-6.67-5-10-5z"/></svg></div><span class="tab-label">RedMed</span></button>
      <button class="tab" type="button" role="tab" id="tab-911" data-tab="911" aria-selected="false" aria-controls="panel-911" tabindex="-1"><div class="icon-wrap" aria-hidden="true"><svg viewBox="0 0 24 24" focusable="false"><path fill-rule="evenodd" clip-rule="evenodd" d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm3.5 5.5-2.5 7.5-7.5 2.5 2.5-7.5 7.5-2.5z"/></svg></div><span class="tab-label">911</span></button>
      <button class="tab" type="button" role="tab" id="tab-aid" data-tab="aid" aria-selected="false" aria-controls="panel-aid" tabindex="-1"><div class="icon-wrap" aria-hidden="true"><svg viewBox="0 0 24 24" focusable="false"><path d="M17 6h-2.2l-.6-1.2A2 2 0 0012.4 4h-.8a2 2 0 00-1.8.8L9.2 6H7a3 3 0 00-3 3v8a3 3 0 003 3h10a3 3 0 003-3V9a3 3 0 00-3-3zm-1.25 7.75h-3v3h-1.5v-3h-3v-1.5h3v-3h1.5v3h3v1.5z"/></svg></div><span class="tab-label">Aid</span></button>
    </div>
    <div class="home-pill" aria-hidden="true"></div>
  </nav>
```

## What the shell renders

- Skip link "Skip To Card"
- `.app` column, max-width `--page-max`, centered
- Active panel only (`.panel.active`)
- Bottom `.tabbar` with RedMed / 911 / Aid and a home pill
- SOS light overlay `#sosLightFlash` is empty until the alarm is armed (not shown in the resting layout)

## RedMed panel (default, phone)

Top to bottom:
1. Help row: device view chips (Auto Phone Tablet Wide) + Help link. Hidden in the owner app embed.
2. Centered note: "Tap To Scan · No Login · No Server · No App" (hidden once a profile is painted)
3. Logo (circle-cropped BrandLogo) + name "RedMed" + status "Not Linked"
4. Empty state card when no `#d=`: pill No Patient, heading, one sentence, foot "911 and Aid still work on this phone."
5. When `#d=` decodes: identity card (Name, Birth Date, Blood Type, Organ Donor, Pregnant, Deaf / Vision Impaired, Notes) then disclosure lists (Allergies, Medicines, Conditions, Contacts)

## 911 panel

Ghost "911" watermark, Help link, Refresh + Copy Coordinates, GPS card, SOS · Locate Me, short survival note, Call 112, seizure timer, two info cards (Roadside First Response, What To Tell 112).

## Aid panel

Help link, accordion panes (Crash & Head, Bleeding, Not Breathing, Choking, Shock, Burns · Cold · Heat, Seizure) each opening topic rows. Topic opens a full sheet with Back. Two footer notes. No maps, no server.
