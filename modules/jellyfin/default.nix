{
  config,
  lib,
  ...
}:
let
  cfg = config.services.jellyfin;
in
{
  imports = [
    ./branding
    ./encoding
    ./libaries
    ./metadata
    ./network
    ./options.nix
    ./plugins
    ./system
    ./users
    ./apiKeyService.nix
    ./setupWizardService.nix
  ];

  config = lib.mkIf (cfg.enable && cfg.declarative.enable) {
    assertions = [
      {
        assertion = lib.any (user: user.policy.isAdministrator) (lib.attrValues cfg.users);
        message = "At least one Jellyfin user must have policy.isAdministrator = true.";
      }
      {
        assertion = cfg.system.cacheSize >= 3;
        message = "services.jellyfin.system.cacheSize must be at least 3 due to Jellyfin's internal caching implementation.";
      }
      {
        assertion = !(cfg.declarative.manageEncoding && cfg.hardwareAcceleration.enable);
        message = "Use either services.jellyfin.declarative.manageEncoding or nixpkgs' hardwareAcceleration.enable, not both.";
      }
    ];

    # Only configuration helpers use this directory. The daemon, accounts,
    # base directories and hardening are supplied by nixpkgs' Jellyfin module.
    systemd.tmpfiles.settings.jellyfinConfiguration = {
      "/run/jellyfin-config".d = {
        mode = "0700";
        user = "root";
        group = "root";
      };
      "${cfg.system.metadataPath}".d = {
        mode = "0700";
        inherit (cfg) user group;
      };
    };
  };
}
