{
  description = "FyxOS: NixOS with the standard Linux library layout";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      nixosModules.default = import ./modules/fhs.nix;
      nixosModules.fhs = self.nixosModules.default;

      checks.${system}.fhs = import ./tests/fhs.nix {
        inherit pkgs;
        module = self.nixosModules.default;
      };

      nixosConfigurations.installer = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs.nixpkgsRev = nixpkgs.rev;
        modules = [
          self.nixosModules.default
          ./installer/iso.nix
        ];
      };
      packages.${system}.iso = self.nixosConfigurations.installer.config.system.build.isoImage;
    };
}
