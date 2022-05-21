#!/bin/bash

set -eu

width=$(tput cols)
height=$(tput lines)
editor_width=84
editor_height=24

if [ "$width" -ge $((editor_width * 2)) ]; then
    orientation="-h"
    size=$((width - editor_width))
elif [ "$height" -ge $((editor_height * 2)) ]; then
    orientation="-v"
    size=$((height - editor_height))
else
    orientation=""
    size=""
fi

if [ -n "$orientation" ]; then
    view_pane=$(tmux split-window -b -d $orientation -l $size -P -F "#D" \
        neomutt -R -F "$HOME"/dotfiles/neomuttrc."$NEOMUTT_PROFILE")

    cleanup () { tmux kill-pane -t "${view_pane}" >/dev/null 2>&1; }

    trap cleanup EXIT ERR
fi

vim "$@"
