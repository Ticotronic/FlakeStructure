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
    catppuccin-sddm
    catppuccin-cursors.macchiatoDark
  ];

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
  };

  # ==========================================
  # Display Manager: SDDM (x11)
  # ==========================================
  services.xserver.enable = true;
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = false;

    # KWin ist auch für Intel deutlich robuster als Weston
    #wayland.compositor = "kwin";
    
    # Der exakte Name des Theme-Ordners
    theme = "catppuccin-macchiato";
    settings = {
      # Hier kannst du weitere SDDM-Einstellungen anpassen, z.B. die Sprache
      # language = "de";
      Theme = {
        # Hier kannst du die Hintergrundfarbe anpassen, falls das Theme das unterstützt
        # backgroundColor = "#1e1e2e";
        CursorTheme = "catppuccin-macchiato-dark-cursors";
      };
    };
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
