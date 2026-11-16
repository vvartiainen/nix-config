// Synthetic System Events objects: never sends Apple Events or opens UI.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';

const source = fs.readFileSync(new URL('../../dotfiles/yabai/mission-control-space.js', import.meta.url), 'utf8');
function scenario({ owner = 'WindowManager', diagnose = false, missing = false,
  refuses = false, closeFails = false, alreadyOpen = false } = {}) {
  let open = alreadyOpen;
  let presses = 0;
  let escapes = 0;
  let launches = 0;
  let now = 0;
  const element = (id, nested = [], attrs = {}) => ({
    attributes: { byName: (name) => ({
      exists: () => name === 'AXIdentifier' || name in attrs,
      value: () => name === 'AXIdentifier' ? id : attrs[name],
    }) },
    uiElements: () => typeof nested === 'function' ? nested() : nested,
  });
  let thumbnails = [element('desktop')];
  const add = element('mc.spaces.add');
  add.actions = { byName: (name) => ({ perform: () => {
    assert.equal(name, 'AXPress');
    presses++;
    if (!refuses) thumbnails.push(element('desktop'));
  } }) };
  const spaces = element('mc.spaces', [
    element('mc.spaces.list', () => thumbnails), ...(missing ? [] : [add]),
  ]);
  const display = element('mc.display', [spaces], { AXDisplayID: 42 });
  // Put another display first to ensure we never press its add button.
  const other = element('mc.display', [], { AXDisplayID: 99 });
  const process = element('', () => !open ? [] : owner === 'Dock'
    ? [element('mc', [other, display])] : [other, display]);
  process.exists = () => true;
  const absent = { exists: () => false };
  const se = {
    uiElementsEnabled: () => true,
    processes: { byName: (name) => name === owner ? process : absent },
    keyCode: (code) => { assert.equal(code, 53); escapes++; if (!closeFails) open = false; },
  };
  const Application = () => se;
  Application.currentApplication = () => ({ doShellScript: () => { launches++; open = true; } });
  const context = vm.createContext({ Application, Date: { now: () => now },
    delay: (seconds) => { now += seconds * 1000; }, console: { log: () => {} } });
  vm.runInContext(source, context);
  let result;
  let error;
  try { result = context.run([diagnose ? 'diagnose' : 'create', '42']); }
  catch (caught) { error = caught; }
  return { open, presses, escapes, launches, result, error };
}
for (const owner of ['Dock', 'WindowManager']) {
  const result = scenario({ owner });
  assert.equal(result.error, undefined);
  assert.equal(result.presses, 1);
  assert.equal(result.escapes, 1);
  assert.equal(result.open, false);
}
const diagnostic = scenario({ diagnose: true });
assert.equal(diagnostic.presses, 0);
assert.equal(JSON.parse(diagnostic.result).owner, 'WindowManager');
assert.equal(diagnostic.open, false);
const existing = scenario({ alreadyOpen: true });
assert.equal(existing.launches, 0);
assert.equal(existing.open, false);
const missing = scenario({ missing: true });
assert.match(missing.error.message, /add button not found/);
assert.equal(missing.open, false);
assert.equal(missing.presses, 0);
const refused = scenario({ refuses: true });
assert.match(refused.error.message, /no new Space/);
assert.equal(refused.presses, 1);
assert.equal(refused.open, false);
assert.match(scenario({ closeFails: true }).error.message, /cleanup failed/);
console.log('Mission Control synthetic behavior checks passed');
