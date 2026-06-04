{ config, pkgs, ... }:

{
  home.username = "roljon";
  home.homeDirectory = "/home/roljon";

  # Diese Version sollte identisch mit deiner system.stateVersion sein
  home.stateVersion = "26.11";
  home.enableNixpkgsReleaseCheck = false; 

  # Lasse Home Manager sich selbst verwalten
  programs.home-manager.enable = true;

  # Niri Konfiguration: Verlinkt den gesamten Ordner 'dotfiles/niri'
  # Der Pfad ist relativ zum Standort dieser home.nix Datei
  xdg.configFile."niri".source = ../dotfiles/niri;

  # Alacritty direkt über Nix konfigurieren
  programs.alacritty = {
    enable = true;
    settings = {
      window = {
        opacity = 0.95;
        padding = { x = 12; y = 12; };
      };
        # Hier können später deine bevorzugten Fonts oder Farbschemata rein
    };
  };

  # Aktiviert SwayOSD (On-Screen Display für Lautstärke/Helligkeit)
  services.swayosd.enable = true;

  ### --  Thunderbird + Profil anlegen mit Passwort -- ##
  programs.thunderbird = {
    enable = true;
    profiles.default = {
      isDefault = true;
    };
  };

  sops.age.sshKeyPaths = [ "/home/roljon/.ssh/id_ed25519" ];  
  sops.defaultSopsFile = ../secrets/mail.yaml;
  sops.secrets."gmx_rj" = {};

  accounts.email.accounts = {
    "r.jongebloed@gmx.de" = {
      primary = true; # Setze dies auf true, falls GMX dein Hauptkonto sein soll
      realName = "Rolf Jongebloed";
      address = "r.jongebloed@gmx.de"; # Oder @gmx.net
      userName = "r.jongebloed@gmx.de"; # Bei GMX ist die volle Adresse der Benutzername

      # Die offiziellen GMX Server-Einstellungen
      imap = {
        host = "imap.gmx.net";
        port = 993;
        tls.enable = true;
      };
      smtp = {
        host = "mail.gmx.net";
        port = 465;
        tls.enable = true;
      };

      thunderbird.enable = true;

      # Das Passwort aus der sops-RAM-Disk auslesen
      passwordCommand = "cat ${config.sops.secrets."gmx_rj".path}";
    };
  };

  ### -- ###

  # --- Waybar Konfiguration ---
  programs.waybar = {
    enable = true;
    
    # Entspricht der config.jsonc
    settings = {
      mainBar = {
        layer = "top";
        position = "top";
        height = 32;
        spacing = 4;
        # niri/workspaces funktioniert out of the box mit Niri!
        modules-left = [ "niri/workspaces" "niri/window" ];
        modules-center = [ "clock" ];
        modules-right = [ "network" "battery" "tray" ];
        
        "clock" = {
          format = "{:%H:%M - %d.%m.%Y}";
        };
      };
    };

    # Entspricht der style.css - ein dunkles, abgerundetes Theme
    style = ''
      * {
        border: none;
        border-radius: 0;
        font-family: "sans-serif"; /* Später kannst du hier eine Nerd Font eintragen */
        font-size: 14px;
        min-height: 0;
      }

      window#waybar {
        background: rgba(30, 30, 46, 0.9);
        color: #cdd6f4;
        border-bottom: 2px solid #89b4fa;
      }

      #workspaces button {
        padding: 0 10px;
        color: #bac2de;
        border-radius: 8px;
        margin: 4px;
      }

      #workspaces button.active {
        background: #89b4fa;
        color: #1e1e2e;
        font-weight: bold;
      }

      #clock, #battery, #network {
        padding: 0 10px;
        background: #313244;
        border-radius: 8px;
        margin: 4px;
      }
    '';
  };
}
