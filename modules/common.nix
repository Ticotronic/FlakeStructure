{ config, pkgs, lib, ... }:

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
  
  # Aktiviert die Bluetooth-Hardware und den dazugehörigen Systemd-Dienst (BlueZ)
  hardware.bluetooth.enable = true; 
  
  # Optional, aber für Laptops sehr praktisch: Bluetooth startet direkt beim Booten
  hardware.bluetooth.powerOnBoot = true; 

  # Installiert ein grafisches Verwaltungstool (blueman-manager) 
  # und stellt das Systemtray-Applet bereit
  services.blueman.enable = true;

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
    vlc
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
      address = [ "192.168.0.203/24" ];
            
      # Optional: Ein DNS-Server für den Tunnel
      dns = [ "192.168.0.1" ];

      # WICHTIG: Den privaten Schlüssel schreiben wir niemals direkt in den Nix-Code!
      # Erstelle diese Datei später manuell auf dem System und lege den Key dort ab.
      privateKeyFile = "/root/wireguard-keys/private";

      peers = [
        {
          # Der öffentliche Schlüssel deines WireGuard-Servers
          publicKey = "8fRB/vfBJVyLzw6yCw/DGv6289AywysZ9Me7BJdBmSE=";

          presharedKeyFile = "/root/wireguard-keys/preshared";
          
          # Die öffentliche IP oder Domain deines Servers und der Port
          endpoint = "ticotronic.ddnss.org:53913";
          
          # Welche IPs sollen durch den Tunnel geleitet werden?
          # "0.0.0.0/0" = Alles (Standard-VPN)do
          # "192.168.178.0/24" = Split-Tunnel (Nur Traffic ins Heimnetz)
          allowedIPs = [ "192.168.0.0/24" ];
          
          # Hält die Verbindung bei restriktiven Firewalls/NAT aktiv
          persistentKeepalive = 25;
        }
      ];
    };
  };
  systemd.services."wg-quick-wg0".wantedBy = lib.mkForce [ ];

  # Füge extraRules ein, damit vpn ohne passwort gestartet werden kann.
  security.sudo.extraRules = [{
      users = [ "roljon" ];
      commands = [
          { command = "/run/current-system/sw/bin/systemctl start wg-quick-wg0"; options = [ "NOPASSWD" ]; }
          { command = "/run/current-system/sw/bin/systemctl stop wg-quick-wg0"; options = [ "NOPASSWD" ]; }
      ];
  }];

  # ==========================================
  # NFS Mount (TrueNAS / Netzwerkspeicher)
  # ==========================================
  fileSystems."/home/roljon/mnt/Premiumize" = {
    device = "192.168.0.145:/mnt/Premiumize/files";
    fsType = "nfs";
    options = [
      "nfsvers=3" # Alternativ "nfsvers=4" oder "nfsvers=3", je nach TrueNAS-Einstellung    
      "noauto"
      "_netdev"
      "x-systemd.automount"
      "x-systemd.idle-timeout=600"
      "x-systemd.device-timeout=5s"
      "x-systemd.mount-timeout=5s"
    ];
  };
    fileSystems."/home/roljon/mnt/Premiumize2" = {
    device = "192.168.0.145:/mnt/Premiumize2/files";
    fsType = "nfs";
    options = [
      "nfsvers=3" # Alternativ "nfsvers=4" oder "nfsvers=3", je nach TrueNAS-Einstellung    
      "noauto"
      "_netdev"
      "x-systemd.automount"
      "x-systemd.idle-timeout=600"
      "x-systemd.device-timeout=5s"
      "x-systemd.mount-timeout=5s"
    ];
  };

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
