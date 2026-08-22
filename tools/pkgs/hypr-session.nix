{ lib, pkgs }:

# Single-file Python program (stdlib only). patchShebangs pins the build's
# python3; hyprctl is resolved from the session PATH at runtime so it always
# matches the running compositor.
pkgs.runCommandLocal "hypr-session"
  {
    nativeBuildInputs = [ pkgs.python3 ];
    meta = with lib; {
      description = "Per-domain save/restore for the 2D Hyprland workspace model";
      license = licenses.mit;
      platforms = platforms.linux;
      mainProgram = "hypr-session";
    };
  }
  ''
    install -Dm755 ${../scripts/hypr-session.py} $out/bin/hypr-session
    patchShebangs $out/bin/hypr-session
    python3 -c "import py_compile; py_compile.compile('$out/bin/hypr-session', cfile='$TMPDIR/c.pyc', doraise=True)"
  ''
