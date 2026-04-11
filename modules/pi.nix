{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    pi
  ];
}
