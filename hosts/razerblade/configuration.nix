{ config, pkgs, lib,  ... }:

{
  networking.hostName = "razerblade";

  # Razer-spezifische Hardware-Unterstützung (Tastaturbeleuchtung etc.)
 # hardware.openrazer = {
 #   enable = true;
 #   users = [ "roljon" ];
 # };

# --- BASIS-MODUS: GPU KOMPLETT AUS ---
# Wir definieren die Bus-IDs global, damit NixOS nie wieder danach fragt
hardware.nvidia.prime.intelBusId = "PCI:0:2:0"; 
hardware.nvidia.prime.nvidiaBusId = "PCI:87:0:0";

# Wir blockieren das Laden jeglicher NVIDIA-Treiber
boot.blacklistedKernelModules = [ "nouveau" "nvidia" "nvidia_drm" "nvidia_modeset" ];

hardware.nvidia.open = false;

# --- SPECIALISATION: HYBRIDER MODUS ---
specialisation = {
  hybrid.configuration = {
    # Dieser Name taucht im Bootmenü auf
    system.nixos.tags = [ "hybrid" ];

    # Blacklist gewaltsam aufheben
    boot.blacklistedKernelModules = lib.mkForce [ "nouveau" ];

    # Nvidia-Treiber aktivieren
    services.xserver.videoDrivers = [ "nvidia" ];

    hardware.nvidia = {
      # Modesetting wird für Wayland (Niri/Sway) zwingend benötigt
      modesetting.enable = true;
      
      # Hier beheben wir den Fehler: Wir nutzen den proprietären Treiber (false) statt des open-source Treibers
      open = false;
      
      # Das Nvidia-Settings-Menü aktivieren
      nvidiaSettings = true;
      
      # Den stabilen Treiber-Zweig auswählen
      package = config.boot.kernelPackages.nvidiaPackages.stable;

      # Diese beiden Zeilen sind der Gamechanger für den Akku:
      powerManagement.enable = true;
      powerManagement.finegrained = false;

      prime = {
        offload = {
          enable = true;
          enableOffloadCmd = true; # Gibt dir den Befehl `nvidia-offload` für die Konsole
        };

        # Trage hier DEINE ermittelten IDs ein:
        #intelBusId = "PCI:0:2:0"; 
        #nvidiaBusId = "PCI:87:0:0"; 
      };
    };
  };
};

  # --- Energieverwaltung ---
  
  # Power-Profiles-Daemon deaktivieren, da er mit TLP in Konflikt steht
  services.power-profiles-daemon.enable = false;

  services.tlp = {
    enable = true;
    settings = {
      # CPU-Verhalten (Leistung am Netzteil, Stromsparen im Akkubetrieb)
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
      CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "power";

      # PCIe Active State Power Management (ASPM) maximieren
      PCIE_ASPM_ON_BAT = "powersupersave";
    };
  };

  # Intel-spezifisches Temperatur- und Leistungsmanagement
  services.thermald.enable = true;

  # Automatisches Tuning von USB- und anderen Geräten
  powerManagement.powertop.enable = true;

  # Verhindert, dass Wayland-Compositor die Nvidia-Karte scannen und wachhalten
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="drm", KERNEL=="card*", DRIVERS=="nvidia", TAG-="seat", TAG-="master-of-seat"
  '';

  system.stateVersion = "24.05"; # Oder die Version, mit der du das Blade initial eingerichtet hast
}
