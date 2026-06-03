{ config, pkgs, ... }:

{
  home.username = "roljon";
  home.homeDirectory = "/home/roljon";

  # Diese Version sollte identisch mit deiner system.stateVersion sein
  home.stateVersion = "26.11";
  home.enableNixpkgsReleaseCheck = false; 

  # Lasse Home Manager sich selbst verwalten
  programs.home-manager.enable = true;

  # Aktiviert SwayOSD (On-Screen Display für Lautstärke/Helligkeit)
  services.swayosd.enable = true;

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
