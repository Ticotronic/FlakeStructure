{ config, pkgs, ... }:

{
  # Deutsches Tastaturlayout in der TTY-Konsole
  console.keyMap = "de";
  
  # Standard-XKB-Layout auf Deutsch setzen (wird von vielen Wayland-Tools gelesen)
  services.xserver.xkb.layout = "de";

  # Regionale Einstellungen
  time.timeZone = "Europe/Berlin";
  i18n.defaultLocale = "de_DE.UTF-8";

  # Niri als Wayland-Compositor
  programs.niri.enable = true;

  # NetworkManager aktivieren
  networking.networkmanager.enable = true;

  # Pakete, die du überall brauchst
  environment.systemPackages = with pkgs; [
    alacritty
    fuzzel
    git
    fastfetch
    brave
    networkmanagerapplet
    brightnessctl
    nemo
    yazi
  ];

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
  };

  # Grafischen Login-Bildschirm (Tuigreet) aktivieren
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd niri-session";
        user = "greeter";
      };
    };
  };

  # Sicherheits-Fix, damit tuigreet reibungslos funktioniert
  systemd.services.greetd.serviceConfig = {
    Type = "idle";
    StandardInput = "tty";
    StandardOutput = "tty";
    StandardError = "journal";
    TTYReset = true;
    TTYVHangup = true;
    TTYVTDisallocate = true;
  };

  # Erlaubt die Nutzung der modernen Nix-Befehle und Flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
}
