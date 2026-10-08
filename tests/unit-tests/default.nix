{
  system ? builtins.currentSystem,
  pkgs ? import <nixpkgs> { inherit system; },
  nixosModules,
}:
let
  inherit (pkgs) lib;
  jellyfinPlugins = import ../../lib/jellyfin-plugins.nix { inherit lib; };
  secrets = import ../../lib/secrets { inherit lib; };
  manifestHash =
    file:
    builtins.convertHash {
      hash = builtins.hashFile "sha256" file;
      hashAlgo = "sha256";
      toHashFormat = "sri";
    };

  # Helper to evaluate a NixOS configuration without building
  evalConfig =
    modules:
    import "${pkgs.path}/nixos/lib/eval-config.nix" {
      inherit system;
      modules = [
        nixosModules
        {
          # Minimal NixOS config stubs needed for evaluation
          nixpkgs.hostPlatform = system;
        }
      ]
      ++ modules;
    };

  # Test helper to assert conditions
  assertTest =
    name: cond:
    pkgs.runCommand "unit-test-${name}" { } ''
      ${lib.optionalString (!cond) "echo 'FAIL: ${name}' && exit 1"}
      echo 'PASS: ${name}' > $out
    '';

  check = name: cond: ''
    ${lib.optionalString (!cond) "echo 'FAIL: ${name}' && exit 1"}
    echo 'PASS: ${name}'
  '';
in
{
  jellyfin-plugin-package-service-generation =
    let
      plugin = pkgs.runCommand "test-plugin-1.0.0" { } ''
        mkdir -p "$out"
        touch "$out/TestPlugin.dll"
      '';
      config = evalConfig [
        {
          services = {
            jellyfin = {
              declarative.enable = true;
              enable = true;
              plugins."Test Plugin".package = plugin;
              users.admin = {
                password = "testpassword";
                policy.isAdministrator = true;
              };
            };
          };
        }
      ];
      systemdUnits = config.config.systemd.services;
      tmpfilesSettings = config.config.systemd.tmpfiles.settings;
      pluginPath = "${config.config.services.jellyfin.dataDir}/plugins";
    in
    pkgs.runCommand "unit-test-jellyfin-plugin-package-service-generation" { } ''
      ${check "plugin service exists" (systemdUnits ? jellyfin-plugins)}
      ${check "plugin tmpfiles directory exists" (
        builtins.hasAttr pluginPath tmpfilesSettings."10-jellyfin"
      )}

      echo 'PASS: jellyfin-plugin-package-service-generation' > $out
    '';

  jellyfin-plugin-source-assertion =
    let
      result = builtins.tryEval (
        let
          config = evalConfig [
            {
              services = {
                jellyfin = {
                  declarative.enable = true;
                  enable = true;
                  plugins."Broken Plugin" = {
                    package = {
                      version = "1.0.0.0";
                    };
                    config.SomeSetting = true;
                  };
                  users.admin = {
                    password = "testpassword";
                    policy.isAdministrator = true;
                  };
                };
              };
            }
          ];
        in
        config.config.system.build.toplevel.drvPath
      );
    in
    assertTest "jellyfin-plugin-source-assertion" (!result.success);

  jellyfin-plugin-repo-service-generation =
    let
      targetAbi = "${pkgs.jellyfin.version}.0";
      manifest = pkgs.writeText "jellyfin-plugin-repo-service-generation.json" (
        builtins.toJSON [
          {
            guid = "c83d86bb-a1e0-4c35-a113-e2101cf4ee6b";
            name = "Intro Skipper";
            versions = [
              {
                version = "12.0.4.0";
                inherit targetAbi;
                sourceUrl = "https://github.com/intro-skipper/intro-skipper/releases/download/12.0/v12.0.4.0/intro-skipper-v12.0.4.0.zip";
              }
            ];
          }
        ]
      );
      config = evalConfig [
        {
          services = {
            jellyfin = {
              declarative.enable = true;
              enable = true;
              system.pluginRepositories = lib.mkForce {
                "Test Repo" = {
                  url = builtins.unsafeDiscardStringContext "file://${manifest}";
                  hash = manifestHash manifest;
                  enabled = true;
                };
              };
              plugins."Intro Skipper" = {
                enable = true;
                package = jellyfinPlugins.fromRepo {
                  version = "12.0.4.0";
                  hash = "sha256-sPEZXGB3s+YI1E9+qJ3EWdKFu2gdqK7LfNjV4QjMlnA=";
                };
              };
              users.admin = {
                password = "testpassword";
                policy.isAdministrator = true;
              };
            };
          };
        }
      ];
      pluginService = config.config.systemd.services.jellyfin-plugins;
    in
    pkgs.runCommand "unit-test-jellyfin-plugin-repo-service-generation" { } ''
      ${check "plugin service exists for repo-managed plugin" (
        config.config.systemd.services ? jellyfin-plugins
      )}
      ${check "repo-managed plugins resolve to package sync commands" (
        lib.hasInfix "Syncing packaged plugin: Intro Skipper" pluginService.script
      )}
      ${check "resolved plugin directory name appears in service script" (
        lib.hasInfix "Intro Skipper_12.0.4.0" pluginService.script
      )}

      echo 'PASS: jellyfin-plugin-repo-service-generation' > $out
    '';

  jellyfin-plugin-repo-relaxed-version-check =
    let
      manifest = pkgs.writeText "jellyfin-plugin-relaxed-version-check.json" (
        builtins.toJSON [
          {
            guid = "486090e1-ca92-46e1-8549-9f6bb914a1d0";
            name = "LAPSE";
            versions = [
              {
                version = "2.0.1.0";
                targetAbi = "10.11.0.0";
                sourceUrl = "https://github.com/Schwponaco-org/lapse-jellyfin-plugin/releases/download/v2.0.1/lapse-jellyfin-plugin-v2.0.1.zip";
              }
            ];
          }
        ]
      );
      config = evalConfig [
        {
          services = {
            jellyfin = {
              declarative.enable = true;
              enable = true;
              system.pluginRepositories = lib.mkForce {
                "LAPSE Repo" = {
                  url = builtins.unsafeDiscardStringContext "file://${manifest}";
                  hash = manifestHash manifest;
                  enabled = true;
                };
              };
              plugins."LAPSE" = {
                enable = true;
                package = jellyfinPlugins.fromRepo {
                  version = "2.0.1.0";
                  hash = "sha256-A9C6P/m17axgmsWC4E3CFP1M/zcSmo+8mgh1cAD4Rls=";
                  relaxVersionCheck = true;
                };
              };
              users.admin = {
                password = "testpassword";
                policy.isAdministrator = true;
              };
            };
          };
        }
      ];
      pluginService = config.config.systemd.services.jellyfin-plugins;
    in
    pkgs.runCommand "unit-test-jellyfin-plugin-repo-relaxed-version-check" { } ''
      ${check "Plugin with incompatible target ABI installed with relaxed version check" (
        lib.hasInfix "LAPSE_2.0.1.0" pluginService.script
      )}

      echo 'PASS: jellyfin-plugin-repo-relax-version-check' > $out
    '';

  jellyfin-plugin-repo-ambiguity-assertion =
    let
      targetAbi = "${pkgs.jellyfin.version}.0";
      manifestA = pkgs.writeText "jellyfin-plugin-repo-a.json" (
        builtins.toJSON [
          {
            guid = "11111111-1111-1111-1111-111111111111";
            name = "Collision Plugin";
            versions = [
              {
                version = "1.0.0.0";
                inherit targetAbi;
                sourceUrl = "https://example.invalid/repo-a.zip";
              }
            ];
          }
        ]
      );
      manifestB = pkgs.writeText "jellyfin-plugin-repo-b.json" (
        builtins.toJSON [
          {
            guid = "22222222-2222-2222-2222-222222222222";
            name = "Collision Plugin";
            versions = [
              {
                version = "1.0.0.0";
                inherit targetAbi;
                sourceUrl = "https://example.invalid/repo-b.zip";
              }
            ];
          }
        ]
      );
      result = builtins.tryEval (
        let
          config = evalConfig [
            {
              services = {
                jellyfin = {
                  declarative.enable = true;
                  enable = true;
                  apiKey = "test-api-key";
                  system.pluginRepositories = lib.mkForce {
                    "Repo A" = {
                      url = builtins.unsafeDiscardStringContext "file://${manifestA}";
                      hash = manifestHash manifestA;
                      enabled = true;
                    };
                    "Repo B" = {
                      url = builtins.unsafeDiscardStringContext "file://${manifestB}";
                      hash = manifestHash manifestB;
                      enabled = true;
                    };
                  };
                  plugins."Collision Plugin" = {
                    package = jellyfinPlugins.fromRepo {
                      version = "1.0.0.0";
                      hash = lib.fakeHash;
                    };
                  };
                  users.admin = {
                    password = "testpassword";
                    policy.isAdministrator = true;
                  };
                };
              };
            }
          ];
        in
        config.config.system.build.toplevel.drvPath
      );
    in
    assertTest "jellyfin-plugin-repo-ambiguity-assertion" (!result.success);

  jellyfin-subtitles =
    let
      config = evalConfig [
        {
          services = {
            jellyfin = {
              declarative.enable = true;
              enable = true;
              apiKey = "test-api-key";

              users.admin = {
                password = "testpassword";
                policy.isAdministrator = true;
              };

              plugins = {
                "Open Subtitles" = {
                  enable = true;
                  config = {
                    Username = "testsubsuser";
                    Password = "opensubs_test_password";
                  };
                };

                subbuzz = {
                  enable = true;
                  config = {
                    EnableOpenSubtitles = true;
                    EnableYifySubtitles = true;
                    MinScore = 60;
                    Cache.SubLifeInMinutes = "Always";
                    SubPostProcessing.EncodeSubtitlesToUTF8 = false;
                  };
                };

                "Subtitle Extract" = {
                  enable = true;
                  config = {
                    ExtractionDuringLibraryScan = true;
                    IncludeTextSubtitles = true;
                    IncludeGraphicalSubtitles = false;
                  };
                };
              };

              libraries."Subtitle Movies" = {
                collectionType = "movies";
                paths = [ "/media/movies" ];
                subtitleFetcherOrder = [
                  "Open Subtitles"
                  "subbuzz"
                ];
                subtitleDownloadLanguages = [
                  "eng"
                  "spa"
                ];
                saveSubtitlesWithMedia = true;
                allowEmbeddedSubtitles = "AllowAll";
                requirePerfectSubtitleMatch = true;
                skipSubtitlesIfAudioTrackMatches = false;
                skipSubtitlesIfEmbeddedSubtitlesPresent = true;
              };
            };
          };
        }
      ];
      pluginService = config.config.systemd.services.jellyfin-plugins;
      jellyfinCfg = config.config.services.jellyfin;
    in
    pkgs.runCommand "unit-test-jellyfin-subtitles" { } ''
      ${check "jellyfin-plugins service exists" (config.config.systemd.services ? jellyfin-plugins)}

      ${check "Open Subtitles plugin sync command in service script" (
        lib.hasInfix "Syncing packaged plugin: Open Subtitles" pluginService.script
      )}
      ${check "subbuzz plugin sync command in service script" (
        lib.hasInfix "Syncing packaged plugin: subbuzz" pluginService.script
      )}
      ${check "Subtitle Extract plugin sync command in service script" (
        lib.hasInfix "Syncing packaged plugin: Subtitle Extract" pluginService.script
      )}

      ${check "Open Subtitles plugin directory name in service script" (
        lib.hasInfix "Open-Subtitles-" pluginService.script
      )}
      ${check "subbuzz plugin directory name in service script" (
        lib.hasInfix "subbuzz-" pluginService.script
      )}
      ${check "Subtitle Extract plugin directory name in service script" (
        lib.hasInfix "Subtitle-Extract-" pluginService.script
      )}

      ${check "subbuzz EnableOpenSubtitles config value" jellyfinCfg.plugins.subbuzz.config.EnableOpenSubtitles}
      ${check "subbuzz EnableYifySubtitles config value" jellyfinCfg.plugins.subbuzz.config.EnableYifySubtitles}
      ${check "subbuzz MinScore config value" (jellyfinCfg.plugins.subbuzz.config.MinScore == 60)}
      ${check "subbuzz Cache.SubLifeInMinutes is 1000001 when set to Always" (
        jellyfinCfg.plugins.subbuzz.config.Cache.SubLifeInMinutes == 1000001
      )}
      ${check "subbuzz SubPostProcessing.EncodeSubtitlesToUTF8 config value" (
        !jellyfinCfg.plugins.subbuzz.config.SubPostProcessing.EncodeSubtitlesToUTF8
      )}

      ${check "Open Subtitles Username config value" (
        jellyfinCfg.plugins."Open Subtitles".config.Username == "testsubsuser"
      )}

      ${check "Subtitle Extract ExtractionDuringLibraryScan config value"
        jellyfinCfg.plugins."Subtitle Extract".config.ExtractionDuringLibraryScan
      }
      ${check "Subtitle Extract IncludeTextSubtitles config value"
        jellyfinCfg.plugins."Subtitle Extract".config.IncludeTextSubtitles
      }
      ${check "Subtitle Extract IncludeGraphicalSubtitles config value" (
        !jellyfinCfg.plugins."Subtitle Extract".config.IncludeGraphicalSubtitles
      )}

      ${check "Subtitle Movies library exists" (jellyfinCfg.libraries ? "Subtitle Movies")}
      ${check "Library subtitle fetcher order" (
        jellyfinCfg.libraries."Subtitle Movies".subtitleFetcherOrder == [
          "Open Subtitles"
          "subbuzz"
        ]
      )}
      ${check "Library subtitle download languages" (
        builtins.elem "eng" jellyfinCfg.libraries."Subtitle Movies".subtitleDownloadLanguages
        && builtins.elem "spa" jellyfinCfg.libraries."Subtitle Movies".subtitleDownloadLanguages
      )}
      ${check "Library saveSubtitlesWithMedia"
        jellyfinCfg.libraries."Subtitle Movies".saveSubtitlesWithMedia
      }
      ${check "Library allowEmbeddedSubtitles" (
        jellyfinCfg.libraries."Subtitle Movies".allowEmbeddedSubtitles == "AllowAll"
      )}
      ${check "Library requirePerfectSubtitleMatch"
        jellyfinCfg.libraries."Subtitle Movies".requirePerfectSubtitleMatch
      }
      ${check "Library skipSubtitlesIfEmbeddedSubtitlesPresent"
        jellyfinCfg.libraries."Subtitle Movies".skipSubtitlesIfEmbeddedSubtitlesPresent
      }
      ${check "Library skipSubtitlesIfAudioTrackMatches" (
        !jellyfinCfg.libraries."Subtitle Movies".skipSubtitlesIfAudioTrackMatches
      )}

      echo 'PASS: jellyfin-subtitles' > $out
    '';

  nested-secret-in-list-jq-filter =
    let
      rawConfig = {
        Entries = [
          {
            Name = "first";
            Value._secret = secretFile;
          }
        ];
      };
      secretFile = pkgs.writeText "entry-value" "s3cr3t-value\n";
      plainFile = pkgs.writeText "plain.json" (builtins.toJSON (secrets.stripSecretRefs rawConfig));
      jqSecrets = secrets.mkNestedJqSecretArgs rawConfig;
    in
    pkgs.runCommand "unit-test-nested-secret-in-list-jq-filter"
      {
        nativeBuildInputs = [ pkgs.jq ];
      }
      ''
        merged=$(
          echo '{"Entries":[]}' \
            | jq \
                ${jqSecrets.flagsString} \
                --argjson plain "$(cat ${plainFile})" \
                '. * $plain | ${lib.concatStringsSep " | " jqSecrets.assignments}'
        )

        value=$(echo "$merged" | jq -r '.Entries[0].Value')
        if [ "$value" != "s3cr3t-value" ]; then
          echo "FAIL: expected substituted value, got '$value'" && exit 1
        fi
        echo 'PASS: nested-secret-in-list-jq-filter' > $out
      '';
}
