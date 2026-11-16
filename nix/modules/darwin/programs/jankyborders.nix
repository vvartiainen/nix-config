{ config, ... }:
{
  # Marks the focused window now that yabai keeps every window opaque.
  services.jankyborders = {
    enable = true;
    # Keep logs directly under Library/Logs; launchd does not create parent
    # directories for StandardOutPath and StandardErrorPath.
    outLogFile = "${config.home.homeDirectory}/Library/Logs/borders.out.log";
    errorLogFile = "${config.home.homeDirectory}/Library/Logs/borders.err.log";
    settings = {
      style = "round";
      width = "5.0";
      hidpi = "on";
      # Catppuccin Macchiato mauve and surface1, matching SketchyBar.
      active_color = "0xffc6a0f6";
      inactive_color = "0xff494d64";
    };
  };
}
