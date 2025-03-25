#!/bin/bash

direction=$1
current=$(i3-msg -t get_workspaces | jq '.[] | select(.focused==true).num')
target=$((current + direction))

i3-msg "move container to workspace number $target; workspace number $target"
