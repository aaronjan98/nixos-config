{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    openai-codex
  ];
}
