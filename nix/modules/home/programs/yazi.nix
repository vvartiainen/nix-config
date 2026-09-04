{ ... }:
{
  programs.yazi = {
    enable = true;
    enableZshIntegration = true;
    # Keep the existing `yy` cwd wrapper rather than the newer `y` default.
    shellWrapperName = "yy";
  };
}
