# Set up agent transcript uploads

1. Create an upload key (empty passphrase, or one available to launchd
   through an SSH agent):

   ```sh
   ssh-keygen -t ed25519 -f ~/.ssh/agent-transcripts -C transcripts@mac
   ```

2. In the homelab checkout, add the public key to `agent_transcript_machines`
   in `incus/agentsview.tf` and deploy it following its AgentsView guide.
3. Set the upload hostname (reachable at home or through Tailscale):

   ```sh
   mkdir -p ~/.config/agent-transcripts
   printf '%s\n' 'history.example.internal' > ~/.config/agent-transcripts/upload-host
   ```

4. Accept the server's host key once; the shell itself is refused:

   ```sh
   ssh -p 2223 -o IdentitiesOnly=yes -i ~/.ssh/agent-transcripts \
     upload@history.example.internal
   ```

5. Apply nix-config, then preview and upload:

   ```sh
   cd ~/prog/nix-config
   just switch
   agent-transcripts-upload --dry-run
   agent-transcripts-upload
   ```

   Check the machine's sessions in the AgentsView web UI. Scheduling and logs
   are in [session history](../agents/sessions.md#session-history).
