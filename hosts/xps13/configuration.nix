{ config, pkgs, ... }:

{
  networking.hostName = "xps13";

  # Erlaubt gezielt diesen alten, unsicheren Broadcom-Treiber fürs XPS
  nixpkgs.config.permittedInsecurePackages = [
    "broadcom-sta-6.30.223.271-59-6.18.33"
  ];

  # Das spezifische Broadcom "wl" Modul in den Kernel laden
  boot.kernelModules = [ "wl" ];
  boot.extraModulePackages = [ config.boot.kernelPackages.broadcom_sta ];

  system.stateVersion = "24.11"; # (Ich habe die 26.11 mal als Tippfehler gewertet, pass das auf deine Original-Version an)
}
