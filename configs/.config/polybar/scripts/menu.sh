#!/bin/bash
CURSOR_POS=$(xdotool getmouselocation --shell)
eval "$CURSOR_POS"
if [ "$X" -ge "0" ] && [ "$X" -le "46" ] && \
   [ "$Y" -ge "1040" ] && [ "$Y" -le "1080" ]; then
    echo "%{B#2f2f2f}%{F#2dcdcd}        %{B-}%{F-}"
else
    echo "%{B#000000}%{F#ffffff}        %{B-}%{F-}"
fi
