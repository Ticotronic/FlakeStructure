{ config, pkgs, lib, ... }:

# Anmeldebildschirm: greetd + Quickshell-Greeter (dotfiles/qs-greeter).
#
# Aufbau:
#   greetd startet als Benutzer "greeter" einen minimalen niri (greeter.kdl).
#   Dieser niri startet per spawn-at-startup das Quickshell-Greeter-Skript und beendet
#   sich danach selbst. Der Greeter spricht ueber Quickshell.Services.Greetd mit greetd,
#   authentifiziert (PAM-Dienst "greetd") und startet am Ende niri-session.
#
# Fallback: Im systemd-boot-Menue gibt es den zusaetzlichen Eintrag "sddm"
# (specialisation) - dort laeuft wie bisher SDDM statt greetd.
let
  # Anzeige-Namen und Sitzungen des Greeters (als JSON an shell.qml uebergeben)
  users = [
    { name = "roljon"; display = "roljon"; }
  ];

  sessions = [
    { name = "niri"; exec = [ "/run/current-system/sw/bin/niri-session" ]; }
  ];

  # Optional: Hintergrundbild (Pfad im Nix-Store oder absolut, muss fuer den Benutzer
  # "greeter" lesbar sein). Leer = Farbverlauf. Beispiel:
  #   wallpaper = "${../wallpapers/login.jpg}";
  wallpaper = "";

  # Quickshell-Konfiguration des Greeters. BatteryIndicator wird aus der Bar-Konfiguration
  # mitgenommen, damit es nur eine Kopie davon gibt.
  greeterConfig = pkgs.runCommand "qs-greeter-config" { } ''
    mkdir -p $out
    cp ${../dotfiles/qs-greeter}/*.qml $out/
    cp ${../dotfiles/quickshell/BatteryIndicator.qml} $out/BatteryIndicator.qml
  '';

  # Wird vom Greeter-niri gestartet. Log: /tmp/qs-greeter.log (Fehlersuche)
  greeterRun = pkgs.writeShellScript "qs-greeter-run" ''
    export GREETER_USERS='${builtins.toJSON users}'
    export GREETER_SESSIONS='${builtins.toJSON sessions}'
    export GREETER_WALLPAPER='${wallpaper}'
    export XCURSOR_THEME="catppuccin-macchiato-dark-cursors"
    export XCURSOR_PATH="/run/current-system/sw/share/icons"
    ${pkgs.quickshell}/bin/quickshell -p ${greeterConfig}/shell.qml > /tmp/qs-greeter.log 2>&1
    # Greeter beendet (Anmeldung erfolgreich oder Absturz) -> Greeter-niri schliessen,
    # damit greetd entweder die Sitzung startet oder den Greeter neu startet.
    ${config.programs.niri.package}/bin/niri msg action quit --skip-confirmation
  '';

  greeterKdl = pkgs.writeText "greeter.kdl" ''
    input {
      keyboard {
        xkb {
          layout "de"
        }
        numlock
      }
      touchpad {
        tap
      }
    }

    cursor {
      xcursor-theme "catppuccin-macchiato-dark-cursors"
    }

    hotkey-overlay {
      skip-at-startup
    }

    spawn-at-startup "${greeterRun}"
  '';
in
{
  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "${config.programs.niri.package}/bin/niri --config ${greeterKdl}";
      user = "greeter";
    };
  };

  # gnome-keyring (Nextcloud-Client-Passwort) beim Login entsperren - wie vorher bei SDDM
  security.pam.services.greetd.enableGnomeKeyring = true;

  # ------------------------------------------------------------------
  # Fallback: SDDM als eigener Boot-Eintrag ("sddm" im systemd-boot-Menue)
  # ------------------------------------------------------------------
  specialisation.sddm.configuration = {
    services.greetd.enable = lib.mkForce false;

    services.displayManager.sddm = {
      enable = true;
      wayland.enable = false;
      theme = "catppuccin-macchiato";
      settings.Theme.CursorTheme = "catppuccin-macchiato-dark-cursors";
    };

    security.pam.services.sddm.enableGnomeKeyring = true;
  };
}
