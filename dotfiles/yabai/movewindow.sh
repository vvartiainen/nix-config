#!/bin/bash

function get_window_id() {
	yabai -m query --windows --window | jq '.id'
}

function move_window() {
	local window_id
	local target=$1
	window_id=$(get_window_id)
	yabai -m window "$window_id" --space "$target"
	yabai -m space --focus "$target"
	yabai -m window --focus "$window_id"
}

move_window "$1"
