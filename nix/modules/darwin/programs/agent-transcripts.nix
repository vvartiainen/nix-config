{
  lib,
  pkgs,
  config,
  ...
}:
let
  home = config.home.homeDirectory;
  # Append-only copy of agent session transcripts for later analysis. The
  # agents prune or rewrite their own stores; this copy never deletes.
  archiveDir = "${config.xdg.dataHome}/agent-transcripts";

  archive = pkgs.writeShellApplication {
    name = "agent-transcripts-archive";
    runtimeInputs = [ pkgs.rsync ];
    text = ''
      umask 077
      # Per-host subdirectory so archives from several machines can be merged.
      host=$(/usr/sbin/scutil --get LocalHostName 2>/dev/null || hostname -s)
      dest="${archiveDir}/$host"

      # copy <name> <source dir>: mirror only the JSONL session files.
      copy() {
        [ -d "$2" ] || return 0
        mkdir -p "$dest/$1"
        rsync -a --prune-empty-dirs \
          --include='*/' --include='*.jsonl' --exclude='*' \
          "$2/" "$dest/$1/"
      }

      copy claude "${home}/.claude/projects"
      copy codex "${home}/.codex/sessions"
      copy pi "${home}/.pi/agent/sessions"
    '';
  };
in
{
  home.packages = [ archive ];

  launchd.agents.agent-transcripts-archive = {
    enable = true;
    config = {
      ProgramArguments = [ (lib.getExe archive) ];
      RunAtLoad = true;
      StartInterval = 3600;
      ProcessType = "Background";
      LowPriorityIO = true;
      StandardErrorPath = "${home}/Library/Logs/agent-transcripts-archive.log";
    };
  };
}
