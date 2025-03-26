#!/bin/bash

direction=$1

workspaces=(`i3-msg -t get_workspaces | jq -r 'map(.num)' | jq -r '.[]'`)

current=$(i3-msg -t get_workspaces | jq -r 'map(select(.focused))' | jq -r '.[]' | jq -r '.nu>

current_index=0
last_index=0
i=0

for n in "${workspaces[@]}"
do
    last_index=$i
    if [ $n == $current ]; then
        current_index=$i
    fi
    ((i++))
done

next_index=0
if [ $direction == "backward" ]; then
    if [ $current_index == 0 ]; then
        next_index=$last_index
    else
        next_index=$(($current_index - 1))
    fi
else
    if [ $current_index == $last_index ]; then
        next_index=0
    else
        next_index=$(($current_index + 1))
    fi
fi

next=${workspaces[$next_index]}
i3-msg workspace $next
