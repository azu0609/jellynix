{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
let
  cfg = config.services.jellyfin;

  util = import ../util.nix { inherit lib; };

  encodingXmlContent = util.mkXmlContent "EncodingOptions" cfg.encoding;
in
{
  imports = [ ./options.nix ];

  config = mkIf (cfg.enable && cfg.declarative.enable && cfg.declarative.manageEncoding) {
    systemd.tmpfiles.settings."10-jellyfin" = mkIf (cfg.encoding.transcodingTempPath != "") {
      "${cfg.encoding.transcodingTempPath}".d = {
        inherit (cfg) user group;
        mode = "0755";
      };
    };

    environment.etc."jellyfin/encoding.xml.template".text = encodingXmlContent;

    systemd.services.jellyfin = {
      restartTriggers = [
        encodingXmlContent
      ];

      serviceConfig.ExecStartPre = mkAfter [
        (pkgs.writeShellScript "jellyfin-setup-encoding-config" ''
          set -eu

          ${pkgs.coreutils}/bin/install -m 640 /etc/jellyfin/encoding.xml.template '${cfg.configDir}/encoding.xml'
        '')
      ];
    };
  };
}
