#!/bin/sh

# skhd already launches commands in the background. The foreground Kitty launch
# also keeps startup errors visible when this script is run from a terminal.
exec kitten quick-access-terminal --instance-group metrics-dashboard \
  --config "$HOME/.config/kitty/metrics.conf" \
  kitty +runpy 'import os, runpy; runpy.run_path(os.path.expanduser("~/.config/kitty/metrics.py"), run_name="__main__")'
