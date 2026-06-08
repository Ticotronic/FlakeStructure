{ config, pkgs, ... }:

{
  # --- Bootloader ---
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # --- Globale Paket-Einstellungen ---
  nixpkgs.config.allowUnfree = true;

  # --- Dein Benutzer-Account ---
  users.users.roljon = {
    isNormalUser = true;
    extraGroups = [ "networkmanager" "wheel" "video" ];
  };

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
#    alacritty
    fuzzel
    git
    fastfetch
    brave
    networkmanagerapplet
    brightnessctl
    nemo
    yazi
    swaylock-effects
    vscode
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

  # ==========================================
  # Systemweite Schriftarten & Icons
  # ==========================================
  fonts.packages = with pkgs; [
    # Die reinen Symbole (sehr wichtig als Fallback für den Browser und Wayland)
    nerd-fonts.symbols-only
    
    # Eine fantastische Programmier-Schriftart inklusive Icons (optional, aber empfohlen)
    nerd-fonts.fira-code
    nerd-fonts.jetbrains-mono
  ];

  # Sagt dem System, dass es diese Fonts als Standard-Fallbacks für fehlende Zeichen nutzen soll
  fonts.fontconfig = {
    defaultFonts = {
      monospace = [ "FiraCode Nerd Font" "JetBrainsMono Nerd Font" ];
    };
  };
}
