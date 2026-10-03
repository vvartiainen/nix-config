// Auth prompts (1Password unlock/sudo, Touch ID, keychain) live above the
// normal window layer, where yabai does not track them, so find them through
// the window server and activate the owning app instead.
ObjC.import('AppKit');
ObjC.import('CoreGraphics');

const owners = /^(1Password.*|coreautha|SecurityAgent)$/;
const windows = ObjC.castRefToObject(
  $.CGWindowListCopyWindowInfo($.kCGWindowListOptionOnScreenOnly, 0),
).js;
const prompt = windows.find((w) => {
  const owner = w.js.kCGWindowOwnerName;
  return owner && owners.test(owner.js) && w.js.kCGWindowLayer.js > 0;
});

if (prompt) {
  $.NSRunningApplication
    .runningApplicationWithProcessIdentifier(prompt.js.kCGWindowOwnerPID.js)
    .activateWithOptions($.NSApplicationActivateIgnoringOtherApps);
}
