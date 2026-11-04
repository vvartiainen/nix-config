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
    ["git add file", "allow"],
    ["npm test", "allow"],
    ["just check", "allow"],
    ["git push origin main", "ask"],
    ["npm publish", "ask"],
    ["nix build .#system", "ask"],
    ["rex run command", "ask"],
    ["sudo command", "deny"],
    ["darwin-rebuild switch", "deny"],
    ["just switch host", "deny"],
    ["git branch -D branch", "ask"],
    ["git branch --show-current", "allow"],
  ]) {
    assert.equal(manager.check({ kind: "tool", surface: "bash", input: { command } }).state,
      expected, command);
  }
  assert.equal(manager.getToolPermission("mcp__rex__run"), "ask");
  assert.equal(manager.getToolPermission("unknown_extension_tool"), "ask");
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
