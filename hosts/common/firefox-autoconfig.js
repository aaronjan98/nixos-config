// Firefox AutoConfig — minimal-chrome support.
//
// Concatenated into $out/lib/firefox/mozilla.cfg by the NixOS firefox wrapper
// (programs.firefox.autoConfig, fed by builtins.readFile). The wrapper emits the
// mandatory "first line must be a comment", so this file starts at real code.
//
// Two jobs:
//   1. Turn on userChrome.css loading.
//   2. Bind Alt+F in every browser window to toggle the auto-hiding chrome.
//
// The stylesheet keys off a `chromeshown` attribute on the root element:
// absent (the default) means the bars auto-hide, present means they are
// pinned open. Defaulting to absent keeps the CSS working on its own if this
// script ever fails to run.

defaultPref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
defaultPref("userchrome.autohide.pinned", false);

(function () {
  const PREF = "userchrome.autohide.pinned";

  try {
    const svc =
      typeof Services !== "undefined"
        ? Services
        : ChromeUtils.importESModule("resource://gre/modules/Services.sys.mjs")
            .Services;

    function apply(win, pinned) {
      const root = win.document.documentElement;
      if (pinned) {
        root.setAttribute("chromeshown", "true");
      } else {
        root.removeAttribute("chromeshown");
      }
    }

    // browser-delayed-startup-finished fires once per browser window, with the
    // window itself as the subject.
    svc.obs.addObserver(function (win) {
      apply(win, svc.prefs.getBoolPref(PREF, false));

      win.addEventListener(
        "keydown",
        function (event) {
          // Bare Alt+F only. KeyF is the physical key, so this survives a
          // remapped layout. Ctrl/Shift/Super combinations are left alone.
          if (
            !event.altKey ||
            event.ctrlKey ||
            event.shiftKey ||
            event.metaKey ||
            event.repeat ||
            event.code !== "KeyF"
          ) {
            return;
          }

          // Swallow it before the menubar's File mnemonic sees it.
          event.preventDefault();
          event.stopPropagation();

          const pinned = !svc.prefs.getBoolPref(PREF, false);
          svc.prefs.setBoolPref(PREF, pinned);

          // Keep every open window in sync; the pref carries the state to
          // windows opened later.
          for (const other of svc.wm.getEnumerator("navigator:browser")) {
            apply(other, pinned);
          }
        },
        true
      );
    }, "browser-delayed-startup-finished");
  } catch (e) {
    try {
      Components.utils.reportError(e);
    } catch (_) {}
  }
})();
