# Create or rotate the agent forge token

Sandboxed agents use their own Forgejo HTTPS token, limited to selected
repositories and kept apart from your own `fj` login. Repeat these steps to
rotate it or change its repositories.

1. In Forgejo, open **Settings → Applications → Generate new token**:
   - **Repository access**: **Specific repositories**, only those agents may
     push to.
   - **Permissions**: `read:repository`, `write:repository`, `read:issue`,
     `write:issue`.

   Without repository-restricted tokens, use a bot account with **Write** on
   those repositories instead.
2. Register it in the agent home, pasting the token when prompted:

   ```sh
   HOME=~/.local/share/agent-forge fj auth add-token --host https://git.lab.vartiainen.io
   ```

3. Verify from Pi:

   ```sh
   cd ~/prog/nix-config && pi
   ```

   Then, in Pi:

   ```sh
   fj pr search -r git.lab.vartiainen.io/ville/nix-config
   git fetch origin
   ```

4. When rotating, delete the old token in Forgejo. To revoke agent access only,
   delete the agent token; your own login keeps working.
