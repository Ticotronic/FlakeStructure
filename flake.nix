{
  description = "Multi-Host NixOS Flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    home-manager = {
      url = "github:nix-community/home-manager";
      # Das verhindert, dass Home Manager eine zweite, eigene Version von nixpkgs herunterlädt
      inputs.nixpkgs.follows = "nixpkgs"; 
    };
  };

  outputs = { self, nixpkgs, nixos-hardware, home-manager, ... }@inputs: {
    nixosConfigurations = {
      
      # 1. Der Dell XPS 13
      xps13 = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          # Passgenaues Hardware-Profil für genau dieses Modell
          nixos-hardware.nixosModules.dell-xps-13-9343
          
          # Lokale Host-Dateien
          ./hosts/xps13/hardware-configuration.nix
          ./hosts/xps13/configuration.nix
          
          # Deine gemeinsame Basis (Niri, Tools, etc.)
          ./modules/common.nix

          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            
            # Hier verbinden wir deinen Benutzer "roljon" mit der neuen Config-Datei
            home-manager.users.roljon = import ./modules/home.nix; 
          }
        ];
      };

      # 2. Das Razer Blade (Vorbereitung für später)
      # razerblade = nixpkgs.lib.nixosSystem {
      #   system = "x86_64-linux";
      #   specialArgs = { inherit inputs; };
      #   modules = [
      #     nixos-hardware.nixosModules.common-pc-laptop
      #     nixos-hardware.nixosModules.common-cpu-intel
      #     ./hosts/razerblade/hardware-configuration.nix
      #     ./hosts/razerblade/configuration.nix
      #     ./modules/common.nix
      #   ];
      # };
    };
  };
}
