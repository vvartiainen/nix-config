#!/bin/bash

CORE_COUNT=$(sysctl -n hw.ncpu)
CPU_PERCENT=$(ps -A -o %cpu= | awk -v cores="$CORE_COUNT" '{sum+=$1} END {printf "%.0f", sum/cores}')

sketchybar --set "$NAME" label="$CPU_PERCENT%"
