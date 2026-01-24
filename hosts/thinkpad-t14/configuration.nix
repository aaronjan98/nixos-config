{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/kanata.nix
    ../../modules/gpg.nix
    ../../modules/tmux.nix
    ../../modules/networkmanager-profiles.nix
    ../../modules/hypr-dispatch.nix
    ../../modules/hypr-idle-lock.nix
    ../../modules/git-server.nix
  ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Bootloader
  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    kernelParams = [ "pcie_aspm=off" ];
  };

  # Networking and Remote Access
  networking = {
    hostName = "nixos";
    networkmanager = {
      enable = true;
      settings = {
        connection = {
	  "wifi.powersave" = 2;
	};
      };
    };
    firewall = {
      enable = true;
      allowedTCPPorts = [ 22 2222 6969 ];
    };
  };
  programs = {
    nm-applet.enable = true;
    ssh.startAgent = true;
    dconf.enable = true;
  };
  services = {
    openssh.enable = true;
    gnome = {
      gnome-keyring.enable = true;
      gcr-ssh-agent.enable = false;
    };
  };
  aj.gitServer = {
    enable = true;
    addAjToGitGroup = true;
    authorizedKeys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK+2LbKzQXnAojIRQPRsSBe6LwseuXyiyvByfzJA85E2 aj@thinkpad-t14"
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDGb60AEnOZcVGE+gU1ogT8Hen4VKFj/t+Y+/8tKyldvEf3gDpsdQk0q0QQUrmSCIsXATwItxebzGw/LIwTLN0YyRD55dF34UkRvVTHFJNSBnCQnpvlozbr6Q3u1ZHtETzX43ypGbHp7SfSjYFZIxjYQGlP7oXJkiL0kUvrFqh7cslIZl62/FzCsZIxJLojlWlscHMnYIqxlgSs5EZZ02sVp4/q85YkfNqL+j00rzD634bLTE/AbsKrcr37jLQkvlWMZU25B2owOjPFg0zb7G0dOE7q7g688MqUkWl/my4L6giKo27pov7abLJWEuvRYvViMGMegcPbSA4IpoRtYUMiBV1G9jIUgPxjfovdZzIh5OkqoFjawa299VaY/G6ZPc9GYVuy8w+gLBF+LQZfyDojBEIKSlx/JtDOQd90iepr6eoQZrX6G6AsswhWOswtWY8vXOHohGVUuAjHujKLxv212c1G1LIhBYLGRtV5wxVnR4wMcEc9gUL9iVScwmM/Ohs= aaronjan98@gmail.com"
    ];
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
  # If this ever fails (option not found), fall back to:
  # services.xserver.desktopManager.plasma5.enable = true;

  # secrets and keys
  system.activationScripts.users.deps = [ "setupSecrets" ];
  systemd.tmpfiles.rules = [ "d /run/sops-nix 0750 root root -" ];
  sops = {
    defaultSopsFile = ../../secrets/users.yaml;
    age.keyFile = "/var/lib/sops-nix/key.txt";
  };
  sops.secrets = {
    "passwords/aj" = { key = "passwords_aj"; path = "/run/sops-nix/passwords_aj"; };
    "passwords/root" = { key = "passwords_root"; path = "/run/sops-nix/passwords_root"; };
  };

  # unfree packages
  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (lib.getName pkg) [
      "discord"
      "vesktop"
      "obsidian"
      "protonvpn-gui"
      "slack"
      "vscode-extension-MS-python-vscode-pylance"
      "vscode-extension-ms-python-python"
      "vscode-extension-ms-toolsai-jupyter"
      "vscode-extension-ms-toolsai-jupyter-keymap"
      "vscode-extension-ms-toolsai-jupyter-renderers"
    ];

  # Users
  users.users.root.hashedPasswordFile = config.sops.secrets."passwords/root".path;

  users.users.aj = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "input" ];
    shell = pkgs.bash;
    hashedPasswordFile = config.sops.secrets."passwords/aj".path;
    packages = with pkgs; [
      vesktop
      element-desktop
      obsidian
      protonvpn-gui
      slack
    ];
  };

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
  services.blueman.enable = true; # GUI fallback

  # modules / packages
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-hyprland
      xdg-desktop-portal-gtk
    ];
  };
  environment.etc."kanata/kanata-internal.kbd".source = ./kanata/kanata-internal.kbd;
  environment.sessionVariables = {
    TERMINAL = "kitty";
    XCURSOR_THEME = "Adwaita";
    XCURSOR_SIZE = "24";
    ELECTRON_OZONE_PLATFORM_HINT = "wayland";
    QT_QPA_PLATFORM = "wayland";
    QT_SCALE_FACTOR = "1";
    GSETTINGS_SCHEMA_DIR =
      "${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}/glib-2.0/schemas";
  };
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
  systemd.services.flatpak-repo = {
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.flatpak ];
    script = ''
      flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    '';
  };
  systemd.packages = [ pkgs.libinput-gestures ];
  environment.systemPackages = with pkgs; [
    # Gnome & System utilities
    glib
    gsettings-desktop-schemas

    # Terminal & Shell
    kitty
    zoxide
    fzf

    # Text Editors
    neovim
    vim

    # System Monitoring
    btop
    htop

    # File & Text Tools
    bat
    ripgrep
    tree
    jq

    # Nix Development
    nil
    nixpkgs-fmt

    # Development Tools
    nodejs
    gcc
    git

    # Networking
    curl
    wget
    iw

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

    # Custom Overlays
    pkgs.breeze-hacked-cursor

    # System commands
    (pkgs.writeShellScriptBin "seed-local-git-server"
      (builtins.readFile ../../scripts/seed-local-git-server.sh)
    )
    # Dev environment
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
      ];
    })
  ];

  # Add a system /etc/xdg/mimeapps.list so xdg-open and file managers prefer Evince for PDFs.
  environment.etc."xdg/mimeapps.list".text = ''
    [Default Applications]
    application/pdf=org.gnome.Evince.desktop
  '';

  system.stateVersion = "25.11";
}

