# IINA

IINA plays web video that Zen hands to it, and with its AirPlay plugin it casts
that file to an Apple TV. Nix installs the app, the plugin and the Zen
extension.

## Send a page to IINA

Right-click a page, link or video in Zen and choose the IINA entry, or click the
toolbar **Open In IINA** button. The extension opens the URL through IINA's
`iina://` handler; launch IINA once after the first install if macOS does not
open it yet.

## Cast to an Apple TV

IINA cannot AirPlay its own playback output, so casting uses the
[AirPlay plugin](https://ozykhan.github.io/iina-airplay/), which streams the
file IINA is playing to the Apple TV and stays the remote. Do not install it
through IINA's plugin store.

Play a file in IINA and either choose **Plugins → AirPlay → Cast to TV** in the
menu bar or start from the sidebar's **Plugins → AirPlay** tab; **Send to TV**
opens the AirPlay picker. The TV starts at the beginning and jumps to IINA's
position, and a cast keeps a second copy of the file in IINA's temp directory
until the cast stops.

## Updates

IINA follows the nixpkgs input, so `just up` updates it; its automatic update
checks are off because Sparkle cannot replace an app in the read-only store. The
plugin version is pinned in the module and has to be bumped by hand together with
its hash. A version change is copied in on the next switch, which also replaces a
copy that IINA updated itself.
