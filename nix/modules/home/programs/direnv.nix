_:
{
  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
    # Skip the long "export +VAR ..." list printed on every load.
    config.global.hide_env_diff = true;
  };

  # nix-direnv's per-project cache and GC roots.
  programs.git.ignores = [ ".direnv/" ];
}
