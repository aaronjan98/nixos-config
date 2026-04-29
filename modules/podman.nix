{ pkgs, ... }:

{
  virtualisation.podman = {
    enable = true;
    # Exposes a Docker-compatible socket at /run/podman/podman.sock.
    # Required for the devcontainer CLI, which looks for a Docker socket.
    # This does NOT alias the `podman` CLI to `docker`.
    dockerSocket.enable = true;
  };

  environment.systemPackages = with pkgs; [
    podman-compose
  ];
}
