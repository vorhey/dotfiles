#!/bin/bash

TARGET_WINDOW=$(tmux display-message -p '#{window_id}')
CURRENT_PANES=$(tmux list-panes -t $TARGET_WINDOW | wc -l)
if [ "$CURRENT_PANES" -lt 16 ]; then
    ROW=$((CURRENT_PANES / 4))
    COLUMN=$((CURRENT_PANES % 4))

    if [ "$COLUMN" -lt 3 ]; then
        tmux split-window -h
    else
        tmux split-window -v
    fi
    tmux select-layout -t $TARGET_WINDOW tiled
else
    echo "Already 4x4 grid."
fi
