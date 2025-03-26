#!/bin/bash
CURSOR_POS=$(xdotool getmouselocation --shell)
eval "$CURSOR_POS"
if [ "$X" -ge "0" ] && [ "$X" -le "53" ] && \
   [ "$Y" -ge "1040" ] && [ "$Y" -le "1080" ]; then
    echo "%{B#373B41}%{F#54D5DE}      %{B-}%{F-}"
else
    echo "%{B#000000}%{F#FFFFFF}      %{B-}%{F-}"
fi
