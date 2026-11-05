// Firefox AutoConfig — minimal-chrome support.
//
// Concatenated into $out/lib/firefox/mozilla.cfg by the NixOS firefox wrapper
// (programs.firefox.autoConfig, fed by builtins.readFile). The wrapper emits the
// mandatory "first line must be a comment", so this file starts at real code.
//
// Three jobs:
//   1. Turn on userChrome.css loading.
//   2. Bind Alt+F in every browser window to toggle the auto-hiding chrome.
//   3. Force on xdg-desktop-portal settings integration (see below).
//
// The stylesheet keys off a `chromeshown` attribute on the root element:
// absent (the default) means the bars auto-hide, present means they are
// pinned open. Defaulting to absent keeps the CSS working on its own if this
// script ever fails to run.

defaultPref("toolkit.legacyUserProfileCustomizations.stylesheets", true);

// widget.use-xdg-desktop-portal.settings: 0 off / 1 on / 2 auto-detect.
// "auto-detect" (the default) gates on a desktop-environment allowlist that
// doesn't recognise Hyprland, so it silently never turns on — website content
// stayed stuck on whatever prefers-color-scheme Firefox guessed at its very
// first run, permanently ignoring both the wallpaper and the (correctly
// flipping) gsettings/portal state. Forcing it to 1 is what actually fixed
// this, confirmed directly: color-scheme and gtk-theme were already flipping
// correctly the whole time and made no difference on their own until this
// was also set. Not on the Preferences-policy allowlist (same class of
// problem as the userChrome.css pref above), so this goes through AutoConfig
// too, not programs.firefox.preferences.
defaultPref("widget.use-xdg-desktop-portal.settings", 1);
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
