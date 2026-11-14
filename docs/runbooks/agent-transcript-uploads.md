# Set up agent transcript uploads

1. Create a dedicated upload key on the Mac:

   ```sh
   ssh-keygen -t ed25519 -f ~/.ssh/agent-transcripts -C transcripts@mac
   ```

   For unattended uploads, use an empty passphrase or make the key available
   through an SSH agent accessible to launchd.
2. In the homelab checkout, add the public key to `agent_transcript_machines`
   in `incus/agentsview.tf` and deploy using its AgentsView setup guide. Each
   key is restricted to its machine's upload directory.
3. Configure the upload hostname locally (replace the example):

   ```sh
   mkdir -p ~/.config/agent-transcripts
   printf '%s\n' 'history.example.internal' > ~/.config/agent-transcripts/upload-host
   ```

   Use the hostname reachable on the home network or through Tailscale. The
   upload account is `upload`, with SSH on port 2223.
4. On the home network or Tailscale, verify and accept the server's SSH host key:

   ```sh
   ssh -p 2223 -o IdentitiesOnly=yes -i ~/.ssh/agent-transcripts \
     upload@history.example.internal
   ```

   Shell access is refused by the server's forced rsync command. The scheduled
   job requires a known host key and never prompts or accepts one automatically.
5. Apply nix-config manually, then preview and upload:

   ```sh
   cd ~/prog/nix-config
   just switch
   agent-transcripts-upload --dry-run
   agent-transcripts-upload
   ```

   The command packages rsync 3 and SSH through Nix. Check the homelab web UI
   for the machine's sessions. See [session history](../agents/sessions.md#session-history)
   for scheduling, offline behavior and logs.
