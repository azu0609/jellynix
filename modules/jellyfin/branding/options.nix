{
  lib,
  ...
}:
with lib;
{
  options.services.jellyfin.branding = {
    customCss = mkOption {
      type = types.lines;
      default = "";
      description = "Custom CSS to be injected into the web client.";
    };

    loginDisclaimer = mkOption {
      type = types.lines;
      default = "";
      description = "Sets the text shown during login underneath the form.";
    };

    splashscreenEnabled = mkOption {
      type = types.bool;
      default = false;
      description = "Enables a splashscreen to be shown during loading.";
    };

    splashscreenLocation = mkOption {
      type = with types; either path str;
      default = "";
      description = "Location of the splashscreen image. Custom images should be in a 16x9 aspect ratio at a minimum size of 1920x1080.";
    };
  };
}
