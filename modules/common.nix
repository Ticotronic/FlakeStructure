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

  # ==========================================
  # WireGuard VPN (wg-quick)
  # ==========================================
  networking.wg-quick.interfaces = {
    # Der Name des Tunnels (meistens wg0)
    wg0 = {
      # Die IP-Adresse, die dein Razer Blade innerhalb des VPNs bekommt
      address = [ "192.168.0.202/32" ];
      
      # Optional: Ein DNS-Server für den Tunnel
      #dns = [ "10.0.0.1" ];

      # WICHTIG: Den privaten Schlüssel schreiben wir niemals direkt in den Nix-Code!
      # Erstelle diese Datei später manuell auf dem System und lege den Key dort ab.
      privateKeyFile = "/root/wireguard-keys/private";

      peers = [
        {
          # Der öffentliche Schlüssel deines WireGuard-Servers
          publicKey = "nWWWwzWV+Y1gaiIwmonQ8pYVu2WsPG2upp0tIuSU6UY=";
          
          # Die öffentliche IP oder Domain deines Servers und der Port
          endpoint = "ticotronic.ddnss.org:53913";
          
          # Welche IPs sollen durch den Tunnel geleitet werden?
          # "0.0.0.0/0" = Alles (Standard-VPN)do
          # "192.168.178.0/24" = Split-Tunnel (Nur Traffic ins Heimnetz)
          allowedIPs = [ "0.0.0.0/0" ];
          
          # Hält die Verbindung bei restriktiven Firewalls/NAT aktiv
          persistentKeepalive = 25;
        }
      ];
    };
  };

  # Füge extraRules ein, damit vpn ohne passwort gestartet werden kann.
  security.sudo.extraRules = [{
      users = [ "roljon" ];
      commands = [
          { command = "/run/current-system/sw/bin/systemctl start wg-quick-wg0"; options = [ "NOPASSWD" ]; }
          { command = "/run/current-system/sw/bin/systemctl stop wg-quick-wg0"; options = [ "NOPASSWD" ]; }
      ];
  }];

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
