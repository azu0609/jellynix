{
  pkgs ? import <nixpkgs> { },
}:
{
  nixosModules.default = import ./modules;
  nixosModules.jellyfin = import ./modules;
  lib.jellyfinPlugins = import ./lib/jellyfin-plugins.nix { inherit (pkgs) lib; };
  lib.buildJellyfinPlugin = import ./lib/build-jellyfin-plugin.nix { inherit pkgs; };
}
