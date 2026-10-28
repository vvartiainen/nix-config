{ pkgs, ... }:
{
  # The configured diff renderer invokes delta, including when imported alone.
  home.packages = [ pkgs.delta ];

  programs.lazygit = {
    enable = true;

    settings = {
      git = {
        diffRenderers = [
          {
            command = "delta --dark --paging=never";
            colorArg = "always";
          }
        ];
        autoFetch = true;
      };

      os = {
        editPreset = "nvim-remote";
      };

      gui = {
        switchTabsWithPanelJumpKeys = true;
        theme = {
          activeBorderColor = [
            "#fab387"
            "bold"
          ];
          inactiveBorderColor = [ "#89b4fa" ];
          optionsTextColor = [ "#89b4fa" ];
          selectedLineBgColor = [ "#313244" ];
          cherryPickedCommitBgColor = [ "#45475a" ];
          cherryPickedCommitFgColor = [ "#fab387" ];
          unstagedChangesColor = [ "#f38ba8" ];
          defaultFgColor = [ "#cdd6f4" ];
          searchingActiveBorderColor = [ "#f9e2af" ];
          authorColors."*" = "#b4befe";
        };
      };

      keybinding = {
        universal = {
          scrollUpMain-alt2 = [
            "<ctrl+u>"
            "<ctrl+b>"
          ];
          scrollDownMain-alt2 = [
            "<ctrl+d>"
            "<ctrl+f>"
          ];
          # ö/ä and Ö/Ä match the nvim [ ] and { } mappings on the Finnish layout
          prevTab = [
            "["
            "ö"
          ];
          nextTab = [
            "]"
            "ä"
          ];
          decreaseContextInDiffView = [
            "{"
            "Ö"
          ];
          increaseContextInDiffView = [
            "}"
            "Ä"
          ];
        };
        # Files panel defaults would shadow the ctrl+f/ctrl+b scrolling above
        files = {
          findBaseCommitForFixup = "<ctrl+x>";
          openStatusFilter = "F";
        };
      };
    };
  };
}
