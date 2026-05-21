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
    #../../modules/math-ocr.nix #broken currently
    ../../modules/cliphist.nix
    ../../modules/obsidian-ipc.nix
    ../../modules/ollama.nix
    ../../modules/claude-code.nix
    ../../modules/openai-codex.nix
    ../../modules/opencode.nix
    ../../modules/pi.nix
    ../../modules/caddy.nix
    ../../modules/podman.nix
  ];

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
    };
    resolved.enable = true;
  };

  # Git server — authorizedKeys is a list and merges with whatever each host
  # appends in its own config, so enable here and let hosts add their keys.
  aj.gitServer = {
    enable = true;
    addAjToGitGroup = true;
  };

  # Time zone and locale
  time.timeZone = "America/Los_Angeles";
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
    "hf_token" = { sopsFile = ../../secrets/hf-token.yaml; key = "hf_token"; };
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
    ];

  # Users
  users.users.root.hashedPasswordFile = config.sops.secrets."passwords/root".path;

  users.users.aj = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "input" "video" "scanner" "lp" ];
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
    powerOnBoot = false;
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
    XCURSOR_THEME = "Adwaita";
    XCURSOR_SIZE = "24";
    MOZ_ENABLE_WAYLAND = "1";
    ELECTRON_OZONE_PLATFORM_HINT = "wayland";
    QT_QPA_PLATFORM = "wayland";
    QT_SCALE_FACTOR = "1";
    GSETTINGS_SCHEMA_DIR =
      "${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}/glib-2.0/schemas";
  };
  environment.extraInit = ''
    export HUGGING_FACE_HUB_TOKEN="$(cat ${config.sops.secrets."hf_token".path})"
    export CONTEXT7_API_KEY="$(cat ${config.sops.secrets."context7_api_key".path})"
    export OPENCODE_ZEN_API_KEY="$(cat ${config.sops.secrets."opencode_zen_api_key".path})"
    export FORGEJO_TOKEN="$(cat ${config.sops.secrets."forgejo_token".path})"
  '';
  programs.nix-ld.enable = true;
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };
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
    gemini-cli
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
    quickshell
    swww

    # Applications
    firefox
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
    #pix2tex
    nix-tools.packages.${pkgs.stdenv.hostPlatform.system}.math-ocr

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
}
