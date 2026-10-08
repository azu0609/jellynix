{ config, lib, ... }:
let
  secrets = import ../../lib/secrets { inherit lib; };
in
{
  options.services.jellyfin = {
    declarative = {
      enable = lib.mkEnableOption "declarative Jellyfin configuration, users, libraries and plugins";

      manageEncoding = lib.mkOption {
        type = lib.types.bool;
        default = !config.services.jellyfin.hardwareAcceleration.enable;
        defaultText = lib.literalExpression "!config.services.jellyfin.hardwareAcceleration.enable";
        description = ''
          Write encoding.xml from services.jellyfin.encoding on each start.
          Disabled by default when nixpkgs' hardwareAcceleration is enabled,
          so only one module manages encoding.xml. Hardware device access and
          supplementary groups remain the responsibility of the host.
        '';
      };
    };

    apiKey = secrets.mkSecretOption {
      description = ''
        API key to inject into Jellyfin's database, used by the configuration
        services. Generate one with `openssl rand -hex 16` and pass its runtime
        file using `_secret`. Other Jellyfin API keys are preserved.
      '';
    };
  };
}
