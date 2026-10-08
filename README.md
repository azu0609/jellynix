# Nixflix — Jellyfin only

A Jellyfin-only fork of [kiriwalawren/nixflix](https://github.com/kiriwalawren/nixflix).
It retains the declarative system, network, encoding, branding, metadata, user,
library and plugin configuration, including pinned plugin packages and runtime
`_secret` references.

Import `nixosModules.default` (also exported as `nixosModules.jellyfin`):

```nix
{ inputs, ... }: {
  imports = [ inputs.nixflix.nixosModules.default ];

  services.jellyfin = {
    enable = true;
    declarative.enable = true;
    apiKey._secret = "/run/secrets/jellyfin-api-key";
    users.admin = {
      password._secret = "/run/secrets/jellyfin-admin-password";
      policy.isAdministrator = true;
    };
    libraries.Music = {
      collectionType = "music";
      paths = [ "/mnt/media/Music" ];
    };
  };
}
```

The nixpkgs Jellyfin module owns the daemon, package, user/group, base directories,
firewall and hardware-device access. This module does not create media directories,
assign UIDs/GIDs, grant supplementary groups, or configure a reverse proxy, VPN or
other media services. Provision library paths and permissions in the host config.
`openFirewall` retains nixpkgs' default-port behavior; open custom ports explicitly.

Set `declarative.enable` to opt into configuration management. The nixflix option
schemas now live under `services.jellyfin`, with the same `users`, `libraries`,
`system.pluginRepositories`, `plugins`, and `encoding` structure. Plugin helpers
remain available as `lib.jellyfinPlugins.fromRepo` and `lib.buildJellyfinPlugin`.
Configuration helpers run as root to read runtime secrets, inject the API key and
restart Jellyfin when plugin files change. Persist `services.jellyfin.dataDir`.

`declarative.manageEncoding` writes the full nixflix `encoding` configuration by
default. It defaults to false when nixpkgs' `hardwareAcceleration.enable` is true,
so nixpkgs can manage encoding instead; both writers cannot be enabled together.
GPU permissions and drivers must be configured explicitly by the host.
