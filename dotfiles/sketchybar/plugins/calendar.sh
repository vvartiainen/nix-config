#!/bin/bash

sketchybar --set "$NAME" label="$(date +'%a %d %b')" \
	--set clock label="$(date +'%I:%M %p')"
