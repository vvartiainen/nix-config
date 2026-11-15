# Create or rotate the agent forge token

Sandboxed agents get their own Forgejo token: one restricted to selected
repositories, kept in a sandbox-only home. Inside Pi, `fj` and git use it, so
pushes and forge calls need no SSH key, SSH agent or keychain. Interactive `fj`
outside a sandbox keeps your own login.

Create it again from scratch when rotating, or when a repository joins or leaves
the agent's reach.

1. In Forgejo, open **Settings → Applications**, then **Generate new token**.
   - **Resource owner**: your account.
   - **Repository access**: **Specific repositories**, and select only the
     repositories agents may push to.
   - **Permissions**: `read:repository`, `write:repository`, `read:issue` and
     `write:issue`. A specific-repository token allows no other scopes, and it
     cannot change repository settings, collaborators or visibility.

   An instance without repository-restricted tokens needs a separate bot
   account with **Write** on those repositories instead, and its token.
2. Register the token in the agent home. Paste it when prompted:

   ```sh
   HOME=~/.local/share/agent-forge fj auth add-token --host https://git.lab.vartiainen.io
   ```

   This writes
   `~/.local/share/agent-forge/Library/Application Support/forgejo-cli.forgejo-cli/keys.json`
   with mode 0600 and creates the directories. Your own
   `~/Library/Application Support/forgejo-cli.forgejo-cli/keys.json` is not
   touched, so `fj` outside a sandbox keeps its login.
3. Verify inside a sandbox:

   ```sh
   cd ~/prog/nix-config && pi
   ```

   In Pi, `which fj` is the sandbox wrapper. Use the fully qualified repository
   form the worktree's multiple remotes require:

   ```sh
   fj pr search -r git.lab.vartiainen.io/ville/nix-config
   git fetch origin
   ```

   `git fetch` asks once and then succeeds: a generated Git config rewrites
   `ssh://git@git.lab.vartiainen.io:2222/` to HTTPS and answers credential
   requests from the same token. `gh`, other SSH remotes, the keychain and
   1Password stay unavailable.

Rotate the token by generating a new one and repeating step 2; delete the old
token in Forgejo afterwards. To revoke agent access only, delete the token —
your interactive login is a different token and keeps working.
