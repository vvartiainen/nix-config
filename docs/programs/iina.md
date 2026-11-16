# IINA

IINA plays web video that Zen hands to it, and with its AirPlay plugin it casts
that video to an Apple TV. Homebrew installs the app, and the Zen extension that
sends pages to it is declared in
`nix/modules/home/programs/zen-browser.nix`, so it arrives with the next switch.

## Send a page to IINA

Right-click a page, link or video in Zen and choose the IINA entry, or click the
toolbar **Open In IINA** button. The extension opens the URL through IINA's
`iina://` handler; launch IINA once after the first install if macOS does not
open it yet.

## Cast to an Apple TV

IINA cannot AirPlay its own playback output, so casting uses the
[AirPlay plugin](https://ozykhan.github.io/iina-airplay/): it remuxes the file
IINA is playing into a live HLS stream, hands that to the Apple TV, and stays the
remote.

Install the plugin once through IINA itself, so the bundled helpers keep their
ad-hoc signatures: **IINA → Settings → Plugins → Get Plugins… → AirPlay →
Install**. A package downloaded in a browser is quarantined, and the plugin then
asks for a reinstall.

Play a file in IINA and either choose **Plugins → AirPlay → Cast to TV** in the
menu bar or start from the sidebar's **Plugins → AirPlay** tab; **Send to TV**
opens the AirPlay picker. The TV starts at the beginning and jumps to IINA's
position, and a cast keeps a second copy of the file in IINA's temp directory
until the cast stops.

## Updates

Homebrew installs IINA and leaves updates to its built-in updater, and the plugin
updates through its page under Settings → Plugins. Activation does not upgrade
installed casks.
