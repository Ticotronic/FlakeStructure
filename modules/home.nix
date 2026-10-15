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

  xdg.configFile."autostart/nm-applet.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=nm-applet
    Hidden=true
  '';

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
  sops.defaultSopsFile = ../secrets/passwords.yaml;
  sops.secrets."gmx_rj" = {};
  sops.secrets."nextcloud_caldav" = {};
  # Immich-API-Schluessel (nur Rechte memory.read + asset.view) fuer den Sperrbildschirm.
  # ERST in secrets/passwords.yaml eintragen (sops secrets/passwords.yaml), dann bauen!
  sops.secrets."immich_api_key" = {};

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
    # Quickshell mit QtMultimedia: das nixpkgs-Paket bringt es nicht mit, wird aber
    # fuer die Video-Wiedergabe der Immich-Erinnerungen (LockVideo.qml) gebraucht.
    # Nur ein Wrapper um das normale Paket, es wird nichts neu kompiliert.
    (pkgs.symlinkJoin {
      name = "quickshell-multimedia";
      paths = [ pkgs.quickshell ];
      nativeBuildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/quickshell \
          --prefix QML2_IMPORT_PATH : ${pkgs.qt6.qtmultimedia}/${pkgs.qt6.qtbase.qtQmlPrefix} \
          --prefix QT_PLUGIN_PATH : ${pkgs.qt6.qtmultimedia}/${pkgs.qt6.qtbase.qtPluginPrefix}
      '';
    })
    wirelesstools
    networkmanager
    curl

    (pkgs.writeShellScriptBin "qs-stats" (builtins.readFile ./qs-stats.sh))

    # Immich-Erinnerungen "An diesem Tag" fuer den Sperrbildschirm (LockMemories.qml)
    (pkgs.writeShellScriptBin "qs-immich" ''
      export IMMICH_URL="http://192.168.0.145:30041"
      export IMMICH_KEY_FILE="${config.sops.secrets."immich_api_key".path}"
      export IMMICH_JQ="${pkgs.jq}/bin/jq"
      export IMMICH_CURL="${pkgs.curl}/bin/curl"
      export IMMICH_IP="${pkgs.iproute2}/bin/ip"
      export IMMICH_IWGETID="${pkgs.wirelesstools}/bin/iwgetid"
      # Der API-Schluessel wird nur im Heim-WLAN oder ueber das VPN gesendet.
      # HIER DEINE(N) WLAN-NAMEN EINTRAGEN (mehrere: weitere Strings in die Liste):
      export IMMICH_HOME_SSIDS=${pkgs.lib.escapeShellArg (pkgs.lib.concatStringsSep "\n" [ "FRITZ!Box 6690 JB" ])}
      export IMMICH_VPN_IFACES="wg0"
      ${builtins.readFile ./qs-immich-body.sh}
    '')

    (pkgs.writeShellScriptBin "nextcloud-caldav-fetch" ''
      export NEXTCLOUD_SERVER_URL="https://nc-on-tn.myhome-server.de"
      export NEXTCLOUD_USERNAME="roljon"
      export NEXTCLOUD_CALENDAR_PATH="personal"
      export NEXTCLOUD_PASSWORD_FILE="${config.sops.secrets."nextcloud_caldav".path}"
      ${builtins.readFile ./nextcloud-caldav-fetch-body.sh}
    '')

      (pkgs.writeShellScriptBin "nextcloud-caldav-push" ''
        export NEXTCLOUD_SERVER_URL="https://nc-on-tn.myhome-server.de"
        export NEXTCLOUD_USERNAME="roljon"
        export NEXTCLOUD_CALENDAR_PATH="personal"
        export NEXTCLOUD_PASSWORD_FILE="${config.sops.secrets."nextcloud_caldav".path}"
        ${builtins.readFile ./nextcloud-caldav-push-body.sh}
    '')

    (pkgs.writeShellScriptBin "nextcloud-tasks-discover" ''
      export NEXTCLOUD_SERVER_URL="https://nc-on-tn.myhome-server.de"
      export NEXTCLOUD_USERNAME="roljon"
      export NEXTCLOUD_PASSWORD_FILE="${config.sops.secrets."nextcloud_caldav".path}"
      ${builtins.readFile ./nextcloud-tasks-discover-body.sh}
    '')

    (pkgs.writeShellScriptBin "nextcloud-tasks-fetch" ''
      export NEXTCLOUD_SERVER_URL="https://nc-on-tn.myhome-server.de"
      export NEXTCLOUD_USERNAME="roljon"
      export NEXTCLOUD_PASSWORD_FILE="${config.sops.secrets."nextcloud_caldav".path}"
      ${builtins.readFile ./nextcloud-tasks-fetch-body.sh}
    '')

    (pkgs.writeShellScriptBin "nextcloud-tasks-push" ''
      export NEXTCLOUD_SERVER_URL="https://nc-on-tn.myhome-server.de"
      export NEXTCLOUD_USERNAME="roljon"
      export NEXTCLOUD_PASSWORD_FILE="${config.sops.secrets."nextcloud_caldav".path}"
      ${builtins.readFile ./nextcloud-tasks-push-body.sh}
    '')
  ];

  xdg.configFile."quickshell".source = ../dotfiles/quickshell;

  # Haruna: nur die Shortcuts deklarativ verwalten. haruna.conf bleibt absichtlich
  # unverwaltet, weil Haruna dort Fenstergroesse, Lautstaerke usw. selbst speichert.
  # Neue Shortcuts: in Haruna einstellen, dann ~/.config/haruna/shortcuts.conf hier
  # uebernehmen. force = true, weil Haruna die Datei beim Beenden neu schreibt
  # (ersetzt den Symlink durch eine echte Datei) und HM sonst beim naechsten
  # Switch wegen "would be clobbered" abbrechen wuerde.
  #xdg.configFile."haruna/shortcuts.conf" = {
  #  force = true;
  #  text = ''
  #    [Shortcuts]
  #    playbackSpeedDecreaseAction=-
  #    playbackSpeedIncreaseAction=+
  #  '';
  #};


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
    # WICHTIG: "gtk3" sorgt dafür, dass Qt-Apps (u.a. Quickshell) auch das
    # per gtk.iconTheme gesetzte Papirus-Dark Icon-Theme tatsächlich nutzen.
    # Mit "qtct" würde stattdessen eine separate qt6ct-Konfiguration greifen,
    # die standardmäßig kein Icon-Theme gesetzt hat -> Fallback auf "hicolor".
    platformTheme.name = "gtk3";
  };



}
