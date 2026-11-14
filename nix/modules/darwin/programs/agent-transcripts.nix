{
  lib,
  pkgs,
  config,
  ...
}:
let
  home = config.home.homeDirectory;
  # Append-only copy of agent session transcripts for later analysis. The
  # agents prune or rewrite their own stores; the JSONL copies never delete.
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
      copy copilot "${home}/.copilot/session-state"
      copy pi "${home}/.pi/agent/sessions"

      # Cursor keeps per-project transcripts (.txt or .jsonl) beside other
      # project state; copy only the agent-transcripts directories.
      if [ -d "${home}/.cursor/projects" ]; then
        mkdir -p "$dest/cursor"
        rsync -a --prune-empty-dirs \
          --include='*/' --include='agent-transcripts/**' --exclude='*' \
          "${home}/.cursor/projects/" "$dest/cursor/"
      fi

      # OpenCode keeps sessions in SQLite; take a consistent online backup.
      # This snapshot is replaced each run, so sessions deleted in OpenCode
      # drop out of it.
      db="${config.xdg.dataHome}/opencode/opencode.db"
      if [ -f "$db" ]; then
        mkdir -p "$dest/opencode"
        /usr/bin/sqlite3 "$db" ".backup '$dest/opencode/opencode.db.tmp'"
        mv -f "$dest/opencode/opencode.db.tmp" "$dest/opencode/opencode.db"
      fi
    '';
  };

  uploadSsh = pkgs.writeShellScript "agent-transcripts-ssh" ''
    exec ${lib.getExe pkgs.openssh} -p 2223 \
      -o BatchMode=yes -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes \
      -o ConnectTimeout=10 -o ServerAliveInterval=30 -o ServerAliveCountMax=2 \
      -i ${lib.escapeShellArg "${home}/.ssh/agent-transcripts"} "$@"
  '';

  upload = pkgs.writeShellApplication {
    name = "agent-transcripts-upload";
    runtimeInputs = [ pkgs.rsync ];
    text = ''
      umask 077
      args=()
      if [ "$#" -gt 1 ]; then
        echo "Usage: agent-transcripts-upload [--dry-run]" >&2
        exit 2
      fi
      case "''${1:-}" in
        "") ;;
        --dry-run) args+=(--dry-run --itemize-changes) ;;
        *) echo "Usage: agent-transcripts-upload [--dry-run]" >&2; exit 2 ;;
      esac
      # The endpoint is private host data, configured outside this repo.
      target=${lib.escapeShellArg "${config.xdg.configHome}/agent-transcripts/upload-host"}
      [ -f "$target" ] || exit 0
      IFS= read -r upload_host < "$target" || true
      if [[ ! "$upload_host" =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]*$ ]]; then
        echo "Invalid hostname in $target" >&2
        exit 1
      fi

      # No LAN/tailnet route (or unavailable endpoint) is a quiet skip.
      # Authentication and transfer errors after this check remain visible.
      /usr/bin/nc -z -G 5 -w 5 "$upload_host" 2223 >/dev/null 2>&1 || exit 0

      ${lib.getExe archive}
      host=$(/usr/sbin/scutil --get LocalHostName 2>/dev/null || hostname -s)
      source="${archiveDir}/$host"
      [ -d "$source" ] || exit 0
      # Match the homelab receiver's supported providers; never send symlinks
      # or propagate local deletions. Interrupted uploads retry next hour.
      exec rsync -rtz --timeout=300 --prune-empty-dirs \
        --chmod=D750,F640 \
        --exclude='.*' \
        --include='/claude/' --include='/codex/' --include='/pi/' \
        --exclude='/*' --include='*/' --include='*.jsonl' --exclude='*' \
        -e ${uploadSsh} "''${args[@]}" "$source/" "upload@$upload_host:."
    '';
  };
in
{
  home.packages = [
    archive
    upload
  ];

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

  launchd.agents.agent-transcripts-upload = {
    enable = true;
    config = {
      ProgramArguments = [ (lib.getExe upload) ];
      RunAtLoad = true;
      StartInterval = 3600;
      ProcessType = "Background";
      LowPriorityIO = true;
      StandardOutPath = "${home}/Library/Logs/agent-transcripts-upload.log";
      StandardErrorPath = "${home}/Library/Logs/agent-transcripts-upload.log";
    };
  };
}
