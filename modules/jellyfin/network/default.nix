{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.jellyfin;
  util = import ../util.nix { inherit lib; };
  networkXmlContent = util.mkXmlContent "NetworkConfiguration" cfg.network;
in
{
  imports = [ ./options.nix ];

  config = lib.mkIf (cfg.enable && cfg.declarative.enable) {
    environment.etc."jellyfin/network.xml.template".text = networkXmlContent;

    systemd.services.jellyfin = {
      restartTriggers = [ networkXmlContent ];
      serviceConfig.ExecStartPre = lib.mkAfter [
        (pkgs.writeShellScript "jellyfin-setup-network-config" ''
          set -eu
          ${pkgs.coreutils}/bin/install -m 600 /etc/jellyfin/network.xml.template ${lib.escapeShellArg "${cfg.configDir}/network.xml"}
        '')
      ];
    };

    warnings =
      lib.optional
        (
          cfg.openFirewall && (cfg.network.internalHttpPort != 8096 || cfg.network.internalHttpsPort != 8920)
        )
        "services.jellyfin.openFirewall opens nixpkgs' default ports only; open custom Jellyfin ports explicitly in networking.firewall.";
  };
}
