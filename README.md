# Jellynix

A Jellyfin-only slop fork of [kiriwalawren/nixflix](https://github.com/kiriwalawren/nixflix).

## Usage

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

`declarative.enable` is the opt-in gate for all configuration management. Persist
`services.jellyfin.dataDir`; library paths and permissions must be provisioned by
the host (see [Host responsibilities](#host-responsibilities)).

## Changes from upstream

### Scope

- **Jellyfin only.** Dropped every other service and its module: Sonarr, Radarr,
  Lidarr, Prowlarr, Recyclarr, Seerr, Navidrome, Maintainerr, slskd, qBittorrent,
  SABnzbd, Notif, Postgres, FlareSolverr, and the Arr auto-wiring that came with them.
- **No bundled reverse proxy.** Removed nginx/Caddy virtual-host generation,
  `lib/mkVirtualHosts.nix`, and the `subdomain` / `reverseProxy.expose` options.
- **No VPN confinement.** Removed the VPN netns module, the `jellyfin.vpn.*`
  options and the `vpn-confinement` flake input.
- **No theming.** Removed theme.park support (`nixflix.theme.*`).
- **No docs site / custom packages.** Removed `docs/`, `pkgs/maintainerr` and
  `pkgs/overlay.nix`.

### Built on the nixpkgs module

- Rebased onto `services.jellyfin`; the option namespace moved from
  `nixflix.jellyfin.*` to `services.jellyfin.*`.
- nixpkgs now owns the daemon and its systemd unit, the package, user/group, base
  directories, firewall and hardware-device access. The fork no longer defines any
  of these.
- Enablement changed from `nixflix.enable` + `nixflix.jellyfin.enable` to
  `services.jellyfin.enable` + `services.jellyfin.declarative.enable`.

### Options removed (delegated to nixpkgs or the host)

| Removed | Replacement |
| --- | --- |
| `nixflix.enable` | `services.jellyfin.enable` |
| `jellyfin.enable` | `services.jellyfin.enable` |
| `jellyfin.package` / `user` / `group` | `services.jellyfin.*` (nixpkgs) |
| `jellyfin.dataDir` / `configDir` / `cacheDir` / `logDir` | `services.jellyfin.*` (nixpkgs) |
| `jellyfin.openFirewall` (own ports) | `services.jellyfin.openFirewall` fires nixpkgs' default ports; open custom ports manually |
| `jellyfin.subdomain`, `jellyfin.reverseProxy.expose` | configure a proxy in the host |
| `jellyfin.vpn.enable` / `vpn.namespace` | configure VPN in the host |
| `nixflix.serviceDependencies` | systemd `after`/`wants` in the host |
| `nixflix.mediaUsers` / `mediaDir` / `downloadsDir` / `stateDir` | host config |
| `nixflix.theme.*` | — |
| `nixflix.nginx.*` / `nixflix.caddy.*` | — |

### Encoding

- New `declarative.manageEncoding` option controls writing `encoding.xml`.
- Defaults to `!services.jellyfin.hardwareAcceleration.enable`, so nixpkgs manages
  encoding when hardware acceleration is enabled; an assertion forbids enabling
  both writers at once.
- `encoding.xml` is installed with `ExecStartPre` using `mkAfter`, so the fork no
  longer clobbers other pre-start hooks.

### Libraries

- Removed the implicitly generated `Shows`, `Anime`, `Movies` and `Music` libraries
  that were derived from enabled Arr services.
- Removed automatic media-path creation; the host must create and own library
  paths. The service now declares `RequiresMountsFor` on every configured path.
- `enableRealtimeMonitor` now defaults to `true` (was `!nixflix.notif.jellyfin.enable`).

### Networking

- Removed reverse-proxy, VPN and firewall module logic; only `network.xml` is
  generated (installed to `configDir` with mode `600` and triggering a restart).
- `warnings` fires when `openFirewall` is set with non-default ports, since
  nixpkgs only opens 8096/8920.

### Paths, secrets and runtime state

- Runtime token/state directory moved from `/run/jellyfin` to
  `/run/jellyfin-config` (created `0700 root:root` via tmpfiles).
- All API configuration services (`api-key`, `setup-wizard`, `system-config`,
  `metadata-config`, `branding-config`, `users-config`, `libraries`, `plugins`)
  now set `TimeoutStartSec = 300`.
- `jellyfin-api-key` uses `wants` instead of `requires`, so it can stop Jellyfin
  while rewriting the database and survive that stop.
- `system.metadataPath` defaults to `${dataDir}/metadata`.

### Plugins

- Kept repository-backed, pinned plugin packages and `_secret` references in
  plugin config.
- Plugin helpers remain `lib.jellyfinPlugins.fromRepo` and
  `lib.buildJellyfinPlugin`.
- Removed the implicit AniDB plugin defaults that depended on the Arr modules.
- Removed merge of external secrets (`lib/secrets/mergeSecrets.py`).

### Flake, packaging and tests

- Removed flake inputs `treefmt-nix`, `mkdocs-catppuccin` and `vpn-confinement`.
- Removed docs packages/apps, the package overlay and the `nixosModules.nixflix`
  alias; added the `nixosModules.jellyfin` alias instead.
- `checks` now runs the Jellyfin VM test plus unit tests (previously the full
  multi-service suite); formatter switched to `nixfmt` via a minimal devShell.

## Host responsibilities

This module intentionally does **not**:

- create media directories or assign UIDs/GIDs;
- grant supplementary groups or hardware device access;
- configure a reverse proxy, VPN, firewall exceptions beyond nixpkgs defaults, or
  other media services.

Provision library paths and permissions in the host config. GPU drivers and
hardware-acceleration permissions must likewise be configured explicitly.
