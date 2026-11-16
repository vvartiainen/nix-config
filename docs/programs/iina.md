# IINA

IINA plays web video that Zen hands to it, and with its AirPlay plugin it casts
that file to an Apple TV. Nix installs both, in
`nix/modules/darwin/programs/iina.nix`: the app comes from nixpkgs, and the
plugin release is copied into IINA's plugins directory on activation. The Zen
extension that sends pages to IINA is declared in
`nix/modules/home/programs/zen-browser.nix`.

## Send a page to IINA

Right-click a page, link or video in Zen and choose the IINA entry, or click the
toolbar **Open In IINA** button. The extension opens the URL through IINA's
`iina://` handler; launch IINA once after the first install if macOS does not
open it yet.

## Cast to an Apple TV

IINA cannot AirPlay its own playback output, so casting uses the
[AirPlay plugin](https://ozykhan.github.io/iina-airplay/): it remuxes the file
IINA is playing into a live HLS stream, hands that to the Apple TV, and stays the
remote. Activation copies it to
`~/Library/Application Support/com.colliderli.iina/plugins`, where IINA looks for
plugins, so nothing is installed through IINA's plugin store. The copy carries no
`com.apple.quarantine`, which is what lets the bundled ffmpeg and helper run
under their ad-hoc signatures.

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
