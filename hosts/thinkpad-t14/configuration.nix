{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/kanata.nix
    ../../modules/gpg.nix
    ../../modules/tmux.nix
    ../../modules/networkmanager-profiles.nix
    ../../modules/hypr-dispatch.nix
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
  };
  services = {
    openssh.enable = true;
    gnome = {
      gnome-keyring.enable = true;
      gcr-ssh-agent.enable = false;
    };
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

  # Users
  users.users.root.hashedPasswordFile = config.sops.secrets."passwords/root".path;

  users.users.aj = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "input" ];
    shell = pkgs.bash;
    hashedPasswordFile = config.sops.secrets."passwords/aj".path;
  };

  # Audio (optional, but recommended)
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # modules / packages
  environment.etc."kanata/kanata-internal.kbd".source = ./kanata/kanata-internal.kbd;
  environment.sessionVariables = {
    TERMINAL = "kitty";
    XCURSOR_THEME = "Adwaita";
    XCURSOR_SIZE = "24";
  };
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  # Basic system packages
  systemd.packages = [ pkgs.libinput-gestures ];
  environment.systemPackages = with pkgs; [
    btop
    curl
    fastfetch
    firefox
    git
    gnupg
    htop
    kitty
    neovim
    pass
    pinentry-curses
    tree
    vim
    wget
    fuzzel
    mako
    brightnessctl
    wireplumber
    libinput-gestures
    iw
  ];

  system.stateVersion = "25.11";
}

