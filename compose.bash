#!/bin/bash

set -eu

view_pane=$(tmux split-window -b -d -h -l 50% -P -F "#D" \
    neomutt -R -F "$HOME"/dotfiles/neomuttrc."$NEOMUTT_PROFILE")

cleanup () {
    tmux kill-pane -t "${view_pane}" >/dev/null 2>&1
}

trap cleanup EXIT ERR
vim "$@"
