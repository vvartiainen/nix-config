// Invoked by create-space.sh with osascript -l JavaScript. No Hammerspoon.
// Hierarchy/timing reference: vladdoster/hammerspoon-configuration PR #9.
function run(argv) {
  if (argv.length !== 2 || !/^(create|diagnose)$/.test(argv[0]) || !/^\d+$/.test(argv[1])) {
    throw new Error('Usage: mission-control-space.js create|diagnose <CGDisplayID>');
  }
  const diagnose = argv[0] === 'diagnose';
  const displayID = Number(argv[1]);
  const se = Application('System Events');
  const app = Application.currentApplication();
  app.includeStandardAdditions = true;

  function attribute(element, name) {
    const attr = element.attributes.byName(name);
    return attr.exists() ? attr.value() : null;
  }
  function children(element) { return element ? element.uiElements() : []; }
  function child(element, id) {
    return children(element).find((e) => attribute(e, 'AXIdentifier') === id);
  }
  function displays() {
    const found = [];
    for (const name of ['WindowManager', 'Dock']) {
      const process = se.processes.byName(name);
      if (!process.exists()) continue;
      // WindowManager exposes displays directly; Dock nests them inside mc.
      const root = name === 'Dock' ? child(process, 'mc') : process;
      for (const element of children(root)) {
        if (attribute(element, 'AXIdentifier') === 'mc.display') {
          found.push({ owner: name, element: element,
            id: Number(attribute(element, 'AXDisplayID')) });
        }
      }
    }
    return found;
  }
  function target() {
    for (const display of displays()) {
      if (display.id !== displayID) continue;
      const spaces = child(display.element, 'mc.spaces');
      const add = child(spaces, 'mc.spaces.add');
      if (add) return { owner: display.owner, spaces: spaces, add: add };
    }
    return null;
  }
  function waitFor(probe, seconds) {
    const deadline = Date.now() + seconds * 1000;
    do {
      const value = probe();
      if (value) return value;
      delay(0.1);
    } while (Date.now() < deadline);
    return null;
  }
  function count(spaces) {
    const list = child(spaces, 'mc.spaces.list');
    return list ? children(list).length : 0;
  }

  // Force permission errors before opening Mission Control. Permissions belong
  // to the responsible launcher (skhd, or the terminal for a manual invocation).
  if (!se.uiElementsEnabled()) throw new Error('Accessibility UI scripting is disabled');
  displays();
  let attemptedOpen = false;
  let failure = null;
  let result;
  try {
    if (!displays().length) {
      attemptedOpen = true;
      app.doShellScript('/usr/bin/open -a "Mission Control"');
    }
    const control = waitFor(target, 5);
    if (diagnose) {
      result = JSON.stringify({ displayID: displayID,
        displays: displays().map((d) => ({ owner: d.owner, displayID: d.id })),
        owner: control ? control.owner : null, addButtonFound: Boolean(control) });
      // osascript writes the returned value to stdout; also emit on failure.
      if (!control) console.log(result);
    }
    if (!control) throw new Error('Mission Control add button not found for display ' + displayID);
    if (!diagnose) {
      // AX can expose the button before the opening animation finishes. The
      // reference also waits MCwaitTime before pressing; do not retry the press.
      delay(0.3);
      const before = count(control.spaces);
      if (!before) throw new Error('Mission Control Space thumbnails not available');
      control.add.actions.byName('AXPress').perform();
      if (!waitFor(() => {
        const current = target();
        return current && count(current.spaces) > before;
      }, 5)) throw new Error('Add pressed, but no new Space appeared; inspect Mission Control before retrying');
    }
  } catch (error) {
    failure = error;
  } finally {
    // Escape closes without toggling Mission Control back open. Also send it
    // after a failed open: the UI may still be animating or missing from AX.
    try {
      if (attemptedOpen || displays().length) {
        se.keyCode(53);
        if (!waitFor(() => displays().length === 0, 5)) {
          throw new Error('Mission Control did not close after Escape');
        }
      }
    } catch (error) {
      failure = new Error((failure ? failure.message + '; ' : '') + 'cleanup failed: ' + error.message);
    }
  }
  if (failure) throw failure;
  return result;
}
