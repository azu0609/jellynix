{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
let
  cfg = config.services.jellyfin;

  pluginResolution = import ./resolvePlugins.nix {
    inherit lib pkgs;
    jellyfinVersion = cfg.package.version;
    inherit (cfg.system) pluginRepositories;
    inherit (cfg) plugins;
  };

  enabledPlugins = pluginResolution.resolvedEnabledPlugins;

  configuredEnabledPlugins = filterAttrs (_name: pluginCfg: pluginCfg.enable) cfg.plugins;

  inherit (pluginResolution) packagePluginDirName;

  packagePluginDirNames = mapAttrsToList (_name: pluginCfg: packagePluginDirName pluginCfg.package) (
    filterAttrs (_name: pluginCfg: pluginCfg.package != null) enabledPlugins
  );
in
{
  imports = [
    ./options.nix
    ./pluginsService.nix
    ./fromJson.nix
  ];

  config = mkIf (cfg.enable && cfg.declarative.enable) {
    warnings = pluginResolution.resolutionWarnings;

    assertions = [
      {
        assertion = all (pluginCfg: pluginCfg.package != null) (attrValues configuredEnabledPlugins);
        message = "services.jellyfin.plugins: enabled plugins must define `package`. Use `nixflix.lib.jellyfinPlugins.fromRepo` for repository-backed plugins.";
      }
      {
        assertion = length packagePluginDirNames == length (unique packagePluginDirNames);
        message = "services.jellyfin.plugins contains duplicate package-managed plugin directory names.";
      }
    ];
  };
}
