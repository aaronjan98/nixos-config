{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/kanata.nix
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
  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [ 22 6969 ];

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

  # Users
  users.users.root = {
    # keep the hash you already generated:
    hashedPassword = "";
  };

  users.users.aj = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    hashedPassword = "";
    shell = pkgs.bash;
    packages = with pkgs; [
      tree
    ];
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
    vim
    git
    wget
    curl
    htop
    fastfetch
    firefox
    tree
  ];

  system.stateVersion = "25.11";
}

