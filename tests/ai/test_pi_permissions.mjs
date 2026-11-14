// Run against the pinned extension and fixture-generated policy, without auth.
// Arguments: Pi package directory, unpacked permission package, policy JSON.
import assert from "node:assert/strict";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { pathToFileURL } from "node:url";
import { spawnSync } from "node:child_process";

const [piDir, extensionDir, policyFile] = process.argv.slice(2);
const scratch = mkdtempSync(join(tmpdir(), "pi-permissions-test-"));
process.env.PI_CODING_AGENT_DIR = scratch;
try {
  // Nix ships Pi's CLI as a bundle. Test its real extension loader through RPC;
  // its unbundled SDK files are not a supported runtime entry point here.
  const loaded = spawnSync(process.execPath, [
    join(piDir, "dist/bundle/cli.js"), "--mode", "rpc", "--no-session",
    "--no-extensions", "-e", join(extensionDir, "src/index.ts"),
  ], {
    cwd: scratch,
    env: { ...process.env, PI_SKIP_VERSION_CHECK: "1", PI_TELEMETRY: "0" },
    input: '{"id":"smoke","type":"get_state"}\n',
    encoding: "utf8", timeout: 30000,
  });
  assert.equal(loaded.status, 0, loaded.stderr);
  assert.doesNotMatch(loaded.stderr + loaded.stdout, /Failed to load extension/);
  assert.match(loaded.stdout, /"id":"smoke".*"success":true/);

  const { createJiti } = await import(pathToFileURL(join(piDir, "dist/core/extensions/jiti-loader.js")));
  const jiti = createJiti(import.meta.url, {
    fsCache: false,
    // The policy module only imports getAgentDir. Use Pi's actual config module
    // to avoid importing the unsupported unbundled SDK entry point.
    alias: { "@earendil-works/pi-coding-agent": join(piDir, "dist/config.js") },
  });
  const { loadUnifiedConfig } = await jiti.import(join(extensionDir, "src/config/config-loader.ts"));
  assert.deepEqual(loadUnifiedConfig(policyFile).issues, [], "generated policy must match the pinned schema");
  const { PermissionManager } = await jiti.import(join(extensionDir, "src/policy/permission-manager.ts"));
  const manager = new PermissionManager({ globalConfigPath: policyFile, agentsDir: scratch });
  for (const [command, expected] of [
    ["git status", "allow"],
    ["sed -n 1,80p docs/agent-permissions.md", "allow"],
    ["find . -name '*.nix'", "allow"],
    ["cd nix && rm -rf result", "allow"],
    ["npm publish", "ask"],
    ["git push origin main", "ask"],
    ["nix build .#system", "ask"],
    ["nix run .#system", "ask"],
    ["nix develop", "ask"],
    ["rex run command", "ask"],
    ["rex --help", "allow"],
    ["rex ls --json", "allow"],
    ["rex capture --trim", "ask"],
    ["/etc/profiles/per-user/agent/bin/rex run -- id", "ask"],
    ["'/Applications/Rex.app/Contents/Helpers/Rex Server.rex/Contents/MacOS/rex' run -- id", "ask"],
    ["/Applications/Rex.app/Contents/Helpers/Rex\\ Server.rex/Contents/MacOS/rex run -- id", "ask"],
    ["\"/Applications/Rex.app/Contents/Helpers/Rex Server.rex/Contents/MacOS/rex\" run -- id", "ask"],
    ["kitty --version", "allow"],
    ["kitty @ send-text payload", "ask"],
    ["incus list", "allow"],
    ["incus exec guest -- id", "ask"],
    ["npm install", "ask"],
    ["npm i", "ask"],
    ["uv sync", "ask"],
    ["mise install node", "ask"],
    ["gh auth token", "deny"],
    ["gh auth status --show-token", "deny"],
    ["op read op://vault/item", "deny"],
    ["git reset --hard", "deny"],
    ["git clean -fd", "deny"],
    ["git push origin main --force", "deny"],
    ["git push origin main -f", "deny"],
    ["sudo command", "ask"],
    ["darwin-rebuild switch", "ask"],
    ["just switch host", "ask"],
    ["git push --force origin main", "deny"],
  ]) {
    assert.equal(manager.check({ kind: "tool", surface: "bash", input: { command } }).state,
      expected, command);
  }
  assert.equal(manager.getToolPermission("mcp__rex__run"), "ask");
  assert.equal(manager.getToolPermission("unknown_extension_tool"), "ask");
  for (const tool of ["web_enable", "web_search", "source_check", "fetch_content", "get_search_content"]) {
    assert.equal(manager.getToolPermission(tool), "allow", tool);
  }
  assert.equal(manager.getToolPermission("read"), "allow");
  for (const path of ["/project/.env", "/project/private.pem", "/Users/agent/.pi/agent/auth.json"]) {
    for (const surface of ["path_read", "path_write"]) {
      assert.equal(manager.check({ kind: "path-values", surface, values: [path] }).state,
        "deny", path);
    }
  }
  console.log("Pi extension loading, schema and approval-policy checks passed");
} finally {
  rmSync(scratch, { recursive: true, force: true });
}
