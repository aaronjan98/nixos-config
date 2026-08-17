{ config, lib, pkgs, nix-tools, snippetsDir, ... }:

# Shared configuration for all hosts. Host-specific files import this module
# and then layer their own overrides on top (hostname, kernel params, kanata
# path, hardware config, authorizedKeys, stateVersion).

{
  imports = [
    ../../modules/kanata.nix
    ../../modules/gpg.nix
    ../../modules/tmux.nix
    ../../modules/networkmanager-profiles.nix
    ../../modules/hypr-dispatch.nix
    ../../modules/wol-sauron.nix
    ../../modules/hypr-idle-lock.nix
    ../../modules/git-server.nix
    ../../modules/flatpak-repo.nix
    ../../modules/screenshot-tools.nix
    ../../modules/imgview.nix
    ../../modules/cliphist.nix
    ../../modules/surya-ocr-server.nix
    ../../modules/obsidian-ipc.nix
    ../../modules/ollama.nix
    ../../modules/claude-code.nix
    ../../modules/openai-codex.nix
    ../../modules/opencode.nix
    ../../modules/pi.nix
    ../../modules/caddy.nix
    ../../modules/podman.nix
    ../../modules/syncthing.nix
    ../../modules/sync-leave-preflight.nix
    ../../modules/emacs.nix
  ];

  aj.syncthing.enable = true;
  aj.syncLeavePreflight.enable = true;

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    max-jobs = 1;
    cores = 12;
    download-buffer-size = 268435456;
  };
  zramSwap = {
    enable = true;
    memoryPercent = 50;
  };

  # Bootloader — host config adds kernelParams on top of this
  boot = {
    loader = {
      systemd-boot = {
        enable = true;
        configurationLimit = 10;
      };
      efi.canTouchEfiVariables = true;
    };
  };

  # Networking — host config sets networking.hostName
  networking = {
    networkmanager = {
      enable = true;
      unmanaged = [ "interface-name:tailscale0" ];
      settings = {
        connection = {
          "wifi.powersave" = 2;
        };
      };
      dns = "systemd-resolved";
    };
    firewall = {
      enable = true;
      # allowedTCPPorts = [ 22 6969 ];
      allowedUDPPorts = [ 41641 ];
    };
  };
  programs = {
    nm-applet.enable = true;
    ssh.startAgent = true;
    dconf.enable = true;
  };
  services = {
    openssh = {
      enable = true;
      listenAddresses = [
        { addr = "127.0.0.1"; port = 22; }
        { addr = "::1"; port = 22; }
      ];
    };
    gnome = {
      gnome-keyring.enable = true;
      gcr-ssh-agent.enable = false;
    };
    tailscale = {
      enable = true;
      useRoutingFeatures = "client";
      # extraUpFlags only applies when authKeyFile is set (it feeds the
      # `tailscale up` in tailscaled-autoconnect). Without an auth key that
      # never runs, so a reauth/`tailscale up` can silently drop these prefs.
      # extraSetFlags drives the tailscaled-set unit, which runs `tailscale
      # set` on every boot unconditionally — so --accept-routes actually sticks.
      extraSetFlags = [ "--accept-routes" "--operator=aj" ];
    };
    resolved = {
      enable = true;
      fallbackDns = [ "1.1.1.1" "8.8.8.8" ];
      extraConfig = ''
        [Resolve]
        DNS=100.97.56.82
        Domains=~home
      '';
    };
  };

  # Git server — authorizedKeys is a list and merges with whatever each host
  # appends in its own config, so enable here and let hosts add their keys.
  aj.gitServer = {
    enable = true;
    addAjToGitGroup = true;
  };

  # Time zone follows physical location. automatic-timezoned uses GeoClue2
  # (WiFi geolocation via BeaconDB) + systemd-timedated to update the zone at
  # runtime as these laptops travel — event-driven off network changes, no reboot.
  # The module itself sets `time.timeZone = null`; mkDefault keeps this literal as
  # a lower-priority fallback (used only if the service is disabled) so the two
  # don't conflict. Note: Home Assistant keeps its own LA time_zone in
  # modules/home-assistant.nix — home-automation schedules stay on home time.
  services.automatic-timezoned.enable = true;
  time.timeZone = lib.mkDefault "America/Los_Angeles";
  i18n.defaultLocale = "en_US.UTF-8";

  console = {
    font = "Lat2-Terminus16";
    keyMap = "us";
  };

  # X11 + KDE Plasma
  services.xserver.enable = true;
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;
  environment.plasma6.excludePackages = [ pkgs.kdePackages.dolphin pkgs.kdePackages.dolphin-plugins ];

  # Secrets and keys — ../../secrets/ resolves to the repo root from any
  # hosts/<name>/ depth, so this path is correct here too.
  #
  # Ordering note: neededForUsers=true on the password secrets tells sops-nix
  # to decrypt those files before the users activation script runs, so
  # hashedPasswordFile works on first boot without a manual dep override.
  # API key secrets use group=users/mode=0640 instead of owner=aj so that
  # the chgrp succeeds even before the aj user exists (the users group is
  # always present early in activation).
  systemd.tmpfiles.rules = [ "d /run/sops-nix 0750 root root -" ];
  sops = {
    defaultSopsFile = ../../secrets/users.yaml;
    age.keyFile = "/var/lib/sops-nix/key.txt";
  };
  sops.secrets = {
    "passwords/aj" = {
      key = "passwords_aj";
      path = "/run/sops-nix/passwords_aj";
      neededForUsers = true;
    };
    "passwords/root" = {
      key = "passwords_root";
      path = "/run/sops-nix/passwords_root";
      neededForUsers = true;
    };
    "hf_token" = {
      sopsFile = ../../secrets/hf-token.yaml;
      key = "hf_token";
      group = "users";
      mode = "0640";
    };
    "context7_api_key" = {
      sopsFile = ../../secrets/context7.yaml;
      key = "context7-secret-key";
      group = "users";
      mode = "0640";
    };
    "opencode_zen_api_key" = {
      sopsFile = ../../secrets/opencode.yaml;
      key = "opencode_zen_api_key";
      group = "users";
      mode = "0640";
    };
    "forgejo_token" = {
      sopsFile = ../../secrets/forgejo.yaml;
      key = "forgejo_token";
      group = "users";
      mode = "0640";
    };
  };

  # Unfree packages
  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (lib.getName pkg) [
      "discord"
      "vesktop"
      "obsidian"
      "protonvpn-gui"
      "slack"
      "mathematica"
      "vscode-extension-MS-python-vscode-pylance"
      "vscode-extension-ms-python-python"
      "vscode-extension-ms-toolsai-jupyter"
      "vscode-extension-ms-toolsai-jupyter-keymap"
      "vscode-extension-ms-toolsai-jupyter-renderers"
      "cursor"
      "burpsuite"
      "antigravity-cli"
    ];

  # Users
  users.users.root.hashedPasswordFile = config.sops.secrets."passwords/root".path;

  users.users.aj = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "input" "video" "scanner" "lp" "dialout" ];
    shell = pkgs.bash;
    hashedPasswordFile = config.sops.secrets."passwords/aj".path;
    packages = with pkgs; [
      vesktop
      element-desktop
      protonvpn-gui
      slack
      motrix
      mpv
    ];
  };
  security.sudo.extraRules = [
    {
      users = [ "aj" ];
      commands = [
        { command = "/run/current-system/sw/bin/rsync"; options = [ "NOPASSWD" ]; }
        { command = "/run/current-system/sw/bin/mkdir"; options = [ "NOPASSWD" ]; }
        { command = "/run/current-system/sw/bin/chmod"; options = [ "NOPASSWD" ]; }
        { command = "/run/current-system/sw/bin/install"; options = [ "NOPASSWD" ]; }
      ];
    }
  ];

  # Printing
  services.printing.enable = true;
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };
  # Scanning (ET-2850 via eSCL/AirScan)
  hardware.sane.enable = true;
  hardware.sane.extraBackends = [ pkgs.sane-airscan ];

  # Audio
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };
  services.blueman.enable = true;

  # Modules / packages
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-hyprland
      xdg-desktop-portal-gtk
    ];
  };
  environment.sessionVariables = {
    TERMINAL = "kitty";
    # Cursor theme/size for the user graphical session (reaches Hyprland). Note
    # the SDDM greeter runs before any session and does NOT see sessionVariables,
    # so its cursor size is not controlled here.
    XCURSOR_THEME = lib.mkDefault "Breeze_Hacked";
    XCURSOR_SIZE = lib.mkDefault "32";
    # NixOS has no /usr/share/X11/locale, so libxkbcommon can't find the Compose
    # file and dead-key sequences (AltGr+~ then a → ã, AltGr+6 then e → ê, etc.)
    # silently fail in Wayland terminals. Point apps at the Compose data directly.
    XCOMPOSEFILE = "${pkgs.xorg.libX11}/share/X11/locale/en_US.UTF-8/Compose";
    MOZ_ENABLE_WAYLAND = "1";
    ELECTRON_OZONE_PLATFORM_HINT = "wayland";
    QT_QPA_PLATFORM = "wayland";
    QT_SCALE_FACTOR = "1";
    GSETTINGS_SCHEMA_DIR =
      "${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}/glib-2.0/schemas";
  };
  # Lazy-reference each secret so the pentest specialisation (which drops
  # these from sops.secrets) can evaluate this option without erroring on
  # missing attrs. NixOS evaluates all definitions of `lines`-typed options
  # to determine priority, so a hard reference here would break pentest even
  # though pentest uses `mkForce ""` to discard the value.
  environment.extraInit = let
    exportSecret = name: envVar:
      if config.sops.secrets ? ${name}
      then ''export ${envVar}="$(cat ${config.sops.secrets.${name}.path})"''
      else "";
  in ''
    ${exportSecret "hf_token" "HUGGING_FACE_HUB_TOKEN"}
    ${exportSecret "context7_api_key" "CONTEXT7_API_KEY"}
    ${exportSecret "opencode_zen_api_key" "OPENCODE_ZEN_API_KEY"}
    ${exportSecret "forgejo_token" "FORGEJO_TOKEN"}
  '';
  programs.nix-ld.enable = true;
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };
  # Host-specific Hyprland overrides are sourced by ~/.config/hypr/hyprland.conf.
  # Hosts can override this file; the shared default keeps the include valid.
  environment.etc."hypr/conf.d/99-host.conf".text = lib.mkDefault ''
    # Default pseudo window sizing for shared hosts.
    windowrulev2 = size 1800 980, class:^(firefox|kitty|com\.mitchellh\.ghostty|vesktop|org-jdownloader-update-launcher-JDLauncher|codium|com\.wolfram\.Wolfram\.14\.3)$
    windowrulev2 = size 1800 980, class:^(electron)$, title:.*Obsidian.*
  '';
  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    nerd-fonts.symbols-only
  ];
  fonts.fontconfig.enable = true;

  ### Basic system packages ###
  services.flatpak.enable = true;
  systemd.packages = [ pkgs.libinput-gestures ];
  environment.systemPackages = with pkgs; [
    # Gnome & System utilities
    glib
    gsettings-desktop-schemas
    flatpak

    # Terminal & Shell
    kitty
    ghostty
    neovide
    antigravity-cli
    zoxide
    fzf
    yazi

    # Text Editors
    neovim
    vim
    (vscode-with-extensions.override {
      vscode = vscodium;
      vscodeExtensions = with vscode-extensions; [
        # Python support
        ms-python.python
        ms-python.vscode-pylance

        # Jupyter notebooks
        ms-toolsai.jupyter
        ms-toolsai.jupyter-keymap
        ms-toolsai.jupyter-renderers

        # Additional helpful extensions
        jnoortheen.nix-ide           # Nix language support
        tamasfe.even-better-toml     # TOML support

        # Quality of life
        eamodio.gitlens              # Git integration
        usernamehw.errorlens         # Inline error messages

        # Math
        leanprover.lean4
      ];
    })
    code-cursor
    llmfit
    models
    claude-code

    # System Monitoring
    btop
    htop

    # File & Text Tools
    bat
    ripgrep
    tree
    jq
    socat
    nautilus
    gvfs

    # Nix Development
    nil
    nixpkgs-fmt

    # Development Tools
    nodejs
    gcc
    git
    elan
    lean4

    # AI specific
    llama-cpp

    # Networking
    curl
    wget
    iw
    tailscale
    dnsutils  # nslookup, dig, host, nsupdate

    # Security & GPG
    gnupg
    pass
    pinentry-curses

    # Wayland/Desktop
    fuzzel
    brightnessctl
    hyprsunset
    wireplumber
    pipewire
    pulseaudio
    libinput-gestures
    libnotify
    wtype
    bemoji        # emoji picker (fuzzel + wtype/wl-copy) — bound to Super+. in Hyprland
    quickshell
    swww

    # Applications
    fastfetch
    evince
    libreoffice
    (mathematica.override {
      source = pkgs.requireFile {
        name = "Wolfram_14.3.0_LIN_Bndl.sh";
        sha256 = "sha256-FvcXXijGOcuRA1UFyVvPIyR1YaK/qrkMpLxf+mz+A/c=";
        message = ''
          Wolfram installer missing.

          Sync local distfiles stash from NAS, then add the installer to the Nix store:
            sync-distfiles wolfram
            nix store add-file /var/lib/distfiles/wolfram/Wolfram_14.3.0_LIN_Bndl.sh
        '';
      };
    })
    obs-studio
    songrec
    zotero

    # Custom Overlays
    breeze-hacked-cursor
    nix-tools.packages.${pkgs.stdenv.hostPlatform.system}.math-ocr
    nix-tools.packages.${pkgs.stdenv.hostPlatform.system}.record-session

    # System commands
    (pkgs.writeShellScriptBin "seed-local-git-server"
      (builtins.readFile ../../scripts/seed-local-git-server.sh)
    )
    (pkgs.writeShellScriptBin "new-homelab-repo"
      (builtins.readFile ../../scripts/new-homelab-repo.sh)
    )
    (pkgs.writeShellScriptBin "install-forgejo-hooks"
      (builtins.readFile ../../scripts/install-forgejo-hooks.sh)
    )
    pkgs.tea
  ];
  programs.firefox = {
    enable = true;
    policies = {
      ExtensionSettings = {
        "contextforge-bridge@local" = {
          installation_mode = "force_installed";
          install_url = "file:///home/aj/Repositories/projects/context-harness/d3daf66dd98445f98929-0.1.0.xpi";
        };
      };
    };
  };

  system.activationScripts.cursorExtensions = {
    deps = [ "users" ];
    text = let
      extensions = [
        pkgs.vscode-extensions.foam.foam-vscode
      ];
      extensionDir = ext: "${ext}/share/vscode/extensions";
    in ''
      # Extensions
      mkdir -p /home/aj/.cursor/extensions
      ${pkgs.lib.concatMapStrings (ext: ''
        for extdir in ${extensionDir ext}/*/; do
          name=$(basename "$extdir")
          target="/home/aj/.cursor/extensions/$name"
          if [ ! -e "$target" ]; then
            ln -sf "$extdir" "$target"
          fi
        done
      '') extensions}
      chown -R aj:users /home/aj/.cursor/extensions

      # HyperSnips snippets
      HSNIPS_DIR="/home/aj/.config/Cursor/User/globalStorage/draivin.hsnips/hsnips"
      mkdir -p "$HSNIPS_DIR"
      ln -sf ${snippetsDir}/markdown.hsnips "$HSNIPS_DIR/markdown.hsnips"
      chown -R aj:users /home/aj/.config/Cursor/User/globalStorage/draivin.hsnips
    '';
  };

  environment.etc."xdg/mimeapps.list".text = ''
    [Default Applications]
    application/pdf=org.gnome.Evince.desktop
  '';

  # ============================================================
  # PENTEST SPECIALISATIONS (all hosts)
  #
  # pentest         — tools + hardening, WiFi works (for web app / network testing)
  # pentest-isolated — same + WiFi blacklisted (for maximum OpSec / WiFi attacks)
  #
  # Activate in-place (from default boot):
  #   /run/current-system/specialisation/<name>/bin/switch-to-configuration switch
  # Revert to default:
  #   /nix/var/nix/profiles/system/bin/switch-to-configuration switch
  # ============================================================
  #
  # Shared pentest config — imported by both specialisations to avoid duplication.
  # Defined as a module lambda so it receives the standard NixOS args.
  specialisation =
    let
      pentestCommon = { lib, pkgs, ... }: {
        imports = [ ../../modules/pentest.nix ];

        # VM support
        virtualisation.libvirtd.enable = true;
        virtualisation.spiceUSBRedirection.enable = true;
        users.users.aj.extraGroups = [ "libvirtd" ];
        environment.systemPackages = [ pkgs.virt-manager ];

        # === Tier 1: identity & credential isolation ===
        services.tailscale.enable = lib.mkForce false;
        aj.syncthing.enable = lib.mkForce false;
        services.avahi.enable = lib.mkForce false;
        services.gnome.gnome-keyring.enable = lib.mkForce false;
        programs.ssh.startAgent = lib.mkForce false;

        # API token exports are a no-op when secrets are absent (base extraInit
        # uses `?` checks), so no mkForce needed — and we must NOT use mkForce ""
        # here because that clobbers the security.wrappers PATH injection and
        # breaks sudo.

        # Drop identity-tied secrets; keep login passwords and any secret read
        # at eval time by an imported module (obsidian-ipc reads obsidian/api_key).
        sops.secrets = lib.mkForce {
          "passwords/aj" = {
            key = "passwords_aj";
            path = "/run/sops-nix/passwords_aj";
            neededForUsers = true;
          };
          "passwords/root" = {
            key = "passwords_root";
            path = "/run/sops-nix/passwords_root";
            neededForUsers = true;
          };
          "obsidian/api_key" = {
            sopsFile = ../../secrets/obsidian.yaml;
            format = "yaml";
            key = "obsidian_key";
            owner = "aj";
          };
        };

        # Drop identity-tied chat apps; keep neutral utilities.
        users.users.aj.packages = lib.mkForce (with pkgs; [
          protonvpn-gui
          motrix
          mpv
        ]);

        # === Tier 2: service surface reduction ===
        services.caddy.enable = lib.mkForce false;
        aj.gitServer.enable = lib.mkForce false;
        services.ollama.enable = lib.mkForce false;
        services.open-webui.enable = lib.mkForce false;
        services.printing.enable = lib.mkForce false;

        # === Tier 3: cosmetic surface ===
        hardware.bluetooth.enable = lib.mkForce false;
        services.blueman.enable = lib.mkForce false;
        services.flatpak.enable = lib.mkForce false;
      };
    in
    {
      pentest.configuration = {
        imports = [ pentestCommon ];
      };

      pentest-isolated.configuration = {
        imports = [ pentestCommon ];
        # Blacklist internal WiFi — use a USB dongle or phone tether instead.
        # iwlwifi/iwlmvm: Intel (ThinkPad T14) — mt7925e: MediaTek (Framework 13 AMD)
        boot.blacklistedKernelModules = [ "iwlwifi" "iwlmvm" "mt7925e" ];
      };
    };
}
