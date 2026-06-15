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

    # ==========================================
    # Custom Build: Catnap (Manuelle Kompilierung)
    # ==========================================
    (pkgs.stdenv.mkDerivation {
      pname = "catnap";
      version = "unstable";

      src = pkgs.fetchFromGitHub {
        owner = "iinsertNameHere";
        repo = "catnap";
        rev = "main"; 
        # ACHTUNG: Trage hier wieder den Hash ein, den du im vorherigen Schritt herausgefunden hast!
        hash = "sha256-aYz+VicvB66okrbReiG4ZjqZmndV4XvKQG8G/JbkNns="; 
      };

      # 2. NEU: Der parsetoml-Quellcode (Die fehlende Abhängigkeit)
      parsetomlSrc = pkgs.fetchFromGitHub {
        owner = "NimParsers";
        repo = "parsetoml";
        rev = "master"; 
        # HIER WIEDER DEN HASH-TRICK ANWENDEN (leer lassen für den ersten Versuch):
        hash = "sha256-auJowvsxluHlgMK3kvdmA45PbFqReyxIIP15/t0SXTU="; 
      };

      # Werkzeuge, die zum Bauen (Kompilieren) benötigt werden
      nativeBuildInputs = [ pkgs.nim ];
      
      # C-Bibliotheken, die Catnap zur Laufzeit braucht (für Regex und Fetching)
      buildInputs = with pkgs; [ pcre openssl ];

      # Wir übergeben den Pfad der heruntergeladenen Bibliothek an den Compiler
      buildPhase = ''
        export HOME=$TMPDIR

        # NixOS-Hack: Wir suchen alle Ordner mit .h-Dateien und geben sie dem C-Compiler als Include-Pfad (-I)
        for d in $(find src -name "*.h" -exec dirname {} \; | sort -u); do
          export NIX_CFLAGS_COMPILE="$NIX_CFLAGS_COMPILE -I$PWD/$d"
        done
        
        nim c -d:release --path:$parsetomlSrc/src src/catnap.nim
      '';

      # Wir schieben das fertig kompilierte Programm in den ausführbaren Pfad
      installPhase = ''
        mkdir -p $out/bin
        cp src/catnap $out/bin/
      '';
    })
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
