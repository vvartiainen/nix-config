_: {
  programs.git = {
    enable = true;
    lfs.enable = true;

    # Global ignores, written to ~/.config/git/ignore (git's default excludesFile).
    ignores = [
      ".DS_Store"
      "._*"
      ".AppleDouble"
      ".LSOverride"
      "Icon\r"
      ".Spotlight-V100"
      ".Trashes"
      # Claude Code local state
      "**/.claude/.cc-writes/"
      "**/.claude/settings.local.json"
    ];

    settings = {
      user = {
        name = "Ville Vartiainen";
        email = "12277119+vvartiainen@users.noreply.github.com";
      };

      credential.helper = "osxkeychain";
      init.defaultBranch = "main";
      color.ui = "auto";

      core = {
        editor = "nvim";
        pager = "delta";
      };

      interactive.diffFilter = "delta --color-only";
      # use n and N to move between diff sections
      delta.navigate = true;

      diff = {
        algorithm = "histogram";
        tool = "nvimdiff";
      };
      # nvim.difftool also handles `git difftool --dir-diff` (lazygit ctrl+t on commits)
      difftool.nvimdiff.cmd = ''nvim -c "packadd nvim.difftool" -d "$LOCAL" "$REMOTE"'';

      merge = {
        conflictStyle = "zdiff3";
        tool = "nvimdiff";
      };
      mergetool.nvimdiff = {
        cmd = ''nvim -d "$LOCAL" "$BASE" "$REMOTE" "$MERGED"'';
        trustExitCode = true;
      };

      push.autoSetupRemote = true;
      pull.rebase = true;
      rebase.autoStash = true;
    };
  };
}
