{ ... }:

{
  services.flatpak = {
    uninstallUnmanaged = false;

    remotes = [
      {
        name = "flathub";
        location = "https://dl.flathub.org/repo/flathub.flatpakrepo";
      }
    ];

    packages = [
      "us.zoom.Zoom"
      "org.jdownloader.JDownloader"
    ];
  };
}
