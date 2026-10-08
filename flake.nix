{
  description = "Declarative Jellyfin configuration on top of the nixpkgs NixOS service";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      inherit (nixpkgs) lib;
      perSystem =
        f: lib.genAttrs [ "x86_64-linux" "aarch64-linux" ] (system: f nixpkgs.legacyPackages.${system});
    in
    {
      lib.buildJellyfinPlugin = { pkgs }: import ./lib/build-jellyfin-plugin.nix { inherit pkgs; };
      lib.jellyfinPlugins = import ./lib/jellyfin-plugins.nix { inherit lib; };

      nixosModules.default = import ./modules;
      nixosModules.jellyfin = self.nixosModules.default;

      formatter = perSystem (pkgs: pkgs.nixfmt);
      checks = perSystem (pkgs: {
        jellyfin = import ./tests/vm-tests/jellyfin-basic.nix {
          inherit pkgs;
          inherit (pkgs.stdenv.hostPlatform) system;
          nixosModules = self.nixosModules.default;
        };
        unit-tests = pkgs.linkFarmFromDrvs "jellyfin-unit-tests" (
          lib.attrValues (
            import ./tests/unit-tests {
              inherit pkgs;
              inherit (pkgs.stdenv.hostPlatform) system;
              nixosModules = self.nixosModules.default;
            }
          )
        );
      });
      devShells = perSystem (pkgs: {
        default = pkgs.mkShell {
          packages = [
            pkgs.nixfmt
            pkgs.jq
          ];
        };
      });
    };
}
