# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  networking.hostName = "xps13"; # Wichtig, damit es unterschieden werden kann
  
  # Bootloader (je nachdem, was der Installer gesetzt hat)
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Der User-Account kann hier bleiben, oder später auch in die common.nix
  users.users.roljon = {
    isNormalUser = true;
    extraGroups = [ "networkmanager" "wheel" "video" ];
  };

  # Erlaubt die Installation von proprietären Treibern (wie Broadcom)
  nixpkgs.config.allowUnfree = true;

  # Erlaubt gezielt diesen alten, unsicheren Broadcom-Treiber
  nixpkgs.config.permittedInsecurePackages = [
    "broadcom-sta-6.30.223.271-59-6.18.33"
  ];

  # Das spezifische Broadcom "wl" Modul in den Kernel laden
  boot.kernelModules = [ "wl" ];
  boot.extraModulePackages = [ config.boot.kernelPackages.broadcom_sta ];

  system.stateVersion = "26.11"; # Did you read the comment?

}
