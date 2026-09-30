// Homepage chrome only. No account client. Band fragments are handled by legacy.js.
(function () {
  var root = document.documentElement;
  var dark = window.matchMedia("(prefers-color-scheme: dark)").matches;
  root.dataset.theme = dark ? "dark" : "light";

  var theme = document.getElementById("theme-toggle");
  if (theme) {
    theme.addEventListener("click", function () {
      root.dataset.theme = root.dataset.theme === "dark" ? "light" : "dark";
    });
  }

  var icons = {
    "sun-moon": '<svg viewBox="0 0 24 24" width="1.1em" height="1.1em" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><path d="M12 3a6 6 0 0 0 9 9 9 9 0 1 1-9-9Z"/></svg>',
    "arrow-up-right": '<svg viewBox="0 0 24 24" width="1em" height="1em" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><path d="M7 17 17 7M8 7h9v9"/></svg>',
    "arrow-down": '<svg viewBox="0 0 24 24" width="1em" height="1em" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><path d="M12 5v14M6 13l6 6 6-6"/></svg>',
    radio: '<svg viewBox="0 0 24 24" width="1.1em" height="1.1em" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><path d="M4.9 19.1a10 10 0 0 1 0-14.2M7.8 16.2a6 6 0 0 1 0-8.4M12 13a1 1 0 1 0 0-2 1 1 0 0 0 0 2Z"/></svg>',
    "user-round-check": '<svg viewBox="0 0 24 24" width="1.1em" height="1.1em" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><path d="M16 11l2 2 4-4"/><path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/></svg>',
    "shield-check": '<svg viewBox="0 0 24 24" width="1.1em" height="1.1em" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10Z"/><path d="m9 12 2 2 4-4"/></svg>',
    battery: '<svg viewBox="0 0 24 24" width="1.1em" height="1.1em" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><rect x="2" y="7" width="16" height="10" rx="2"/><path d="M22 11v2"/></svg>',
    smartphone: '<svg viewBox="0 0 24 24" width="1.1em" height="1.1em" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><rect x="7" y="2" width="10" height="20" rx="2"/><path d="M11 18h2"/></svg>',
    nfc: '<svg viewBox="0 0 24 24" width="1.1em" height="1.1em" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><path d="M6 8.3a7 7 0 0 1 0 7.4M9.5 6a10 10 0 0 1 0 12"/><path d="M13 4.5a13 13 0 0 1 0 15"/></svg>',
    "heart-handshake": '<svg viewBox="0 0 24 24" width="1.1em" height="1.1em" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><path d="M19 14c1.5-1.5 2-3.5 1-5s-3-2-4.5-.5L12 12l-3.5-3.5C7 7 5 7 4 8.5s-.5 3.5 1 5L12 21l7-7Z"/></svg>',
    "lock-keyhole": '<svg viewBox="0 0 24 24" width="1.1em" height="1.1em" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><rect x="4" y="11" width="16" height="10" rx="2"/><path d="M8 11V7a4 4 0 0 1 8 0v4"/><circle cx="12" cy="16" r="1"/></svg>',
    "wifi-off": '<svg viewBox="0 0 24 24" width="1.1em" height="1.1em" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><path d="m2 2 20 20M8.5 16.4a5 5 0 0 1 7 0M5 12.5a10 10 0 0 1 4-2.4M12 20h.01"/></svg>',
    plus: '<svg viewBox="0 0 24 24" width="1em" height="1em" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><path d="M12 5v14M5 12h14"/></svg>',
    x: '<svg viewBox="0 0 24 24" width="1em" height="1em" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><path d="M18 6 6 18M6 6l12 12"/></svg>'
  };

  document.querySelectorAll("[data-lucide]").forEach(function (el) {
    var svg = icons[el.getAttribute("data-lucide")];
    if (svg) el.innerHTML = svg;
  });

  function openPrivacy() {
    var dialog = document.getElementById("privacy-dialog");
    if (dialog && dialog.showModal) {
      dialog.showModal();
      document.body.classList.add("modal-open");
    }
  }
  ["privacy-open", "footer-privacy"].forEach(function (id) {
    var button = document.getElementById(id);
    if (button) button.addEventListener("click", openPrivacy);
  });
  document.querySelectorAll("dialog").forEach(function (dialog) {
    var close = dialog.querySelector(".dialog-close");
    if (close) close.addEventListener("click", function () { dialog.close(); });
    dialog.addEventListener("close", function () {
      if (!document.querySelector("dialog[open]")) document.body.classList.remove("modal-open");
    });
  });
})();
