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
  home.packages = with pkgs; [
    quickshell
    wirelesstools
    networkmanager

    (pkgs.writeShellScriptBin "qs-stats" (builtins.readFile ./qs-stats.sh))
  ];

  xdg.configFile."quickshell".source = ../dotfiles/quickshell;


  # ==========================================
  # GTK & QT Theming (für Quickshell & Niri)
  # ==========================================
  gtk = {
    # WICHTIG: Das Hauptmodul muss aktiviert sein, sonst wird iconTheme ignoriert!
    enable = true; 
    
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };

    # Optional: Setzt auch das Fenster-Theme für GTK-Apps auf Adwaita-Dark
    theme = {
      name = "Adwaita-dark";
      package = pkgs.gnome-themes-extra;
    };
  };

  qt = {
    enable = true;
    style.name = "adwaita-dark";
    
    # Der Wayland-Trick: Zwingt Qt-Anwendungen, sich optisch an dein GTK-Theme anzupassen
    platformTheme.name = "qtct"; 
  };



}
