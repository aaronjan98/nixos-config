{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/kanata.nix
    ../../modules/gpg.nix
    ../../modules/tmux.nix
  ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Hostname and networking
  networking.hostName = "nixos";
  networking.networkmanager.enable = true;
  # Remote access
  services.openssh.enable = true;
  programs.ssh.startAgent = true;
  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [ 22 2222 6969 ];

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
    extraGroups = [ "wheel" "networkmanager" ];
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

  # modules
  environment.etc."kanata/kanata-internal.kbd".source = ./kanata/kanata-internal.kbd;

  # Basic system packages
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
  ];

  system.stateVersion = "25.11";
}

