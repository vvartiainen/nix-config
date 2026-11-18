# IINA

IINA plays web video from Zen and casts it to an Apple TV. Nix installs the
app, its AirPlay plugin and the Zen extension.

## Send a page to IINA

Right-click a page, link or video in Zen and choose the IINA entry, or click
**Open In IINA** in the toolbar. Launch IINA once if macOS does not open it.

## Cast to an Apple TV

Play a file in IINA, then choose **Plugins → AirPlay → Cast to TV** (or the
sidebar's **Plugins → AirPlay** tab and **Send to TV**). IINA stays the
remote. Do not install the
[AirPlay plugin](https://ozykhan.github.io/iina-airplay/) through IINA's
plugin store.

## Updates

`just up` updates IINA through nixpkgs; its own update checks are off. The
plugin is pinned in the module: bump its version and hash by hand.
