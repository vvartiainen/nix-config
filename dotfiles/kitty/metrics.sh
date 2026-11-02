#!/bin/sh

# A separate instance preserves both this dashboard and the quick-access shell.
exec kitten quick-access-terminal --detach --instance-group metrics \
  --config "$HOME/.config/kitty/metrics.conf" \
  kitty +runpy 'import os, runpy; runpy.run_path(os.path.expanduser("~/.config/kitty/metrics.py"), run_name="__main__")'
