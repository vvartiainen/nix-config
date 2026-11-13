{ config, userName, ... }:
{
  # Home Manager configures Claude Code; Homebrew tracks the newest release.
  homebrew.casks = [ "claude-code@latest" ];

  # GUI apps such as CodexBar don't read shell variables; without this,
  # their `claude` runs recreate ~/.claude.json.
  launchd.user.envVariables.CLAUDE_CONFIG_DIR =
    config.home-manager.users.${userName}.programs.claude-code.configDir;
}
