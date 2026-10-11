#!/bin/bash

# Print "dark" or "light" based on the terminal's background colour, queried
# with OSC 11 (the same thing codex/claude-code do). Works inside tmux, which
# answers with the attached terminal's background. Exits 1 if nothing answers.

[ -t 0 ] || exit 1
exec 3<>/dev/tty || exit 1

saved=$(stty -g <&3) || exit 1
trap 'stty "$saved" <&3' EXIT
stty raw -echo min 0 time 0 <&3

# Every terminal answers DA1 (\e[c), so its reply ends the wait when OSC 11
# is unsupported or tmux has no colour to report yet.
printf '\033]11;?\033\\\033[c' >&3
reply=
while IFS= read -r -s -d '' -n 1 -t 0.5 -u 3 ch; do
    reply+=$ch
    [[ $reply =~ $'\033'\[\?[0-9\;]*c$ ]] && break
done

[[ $reply =~ rgba?:([0-9a-fA-F]+)/([0-9a-fA-F]+)/([0-9a-fA-F]+) ]] || exit 1

# Channels are 1-4 hex digits each; scale to 0-255
luma=0
for i in 1 2 3; do
    hex=${BASH_REMATCH[$i]}
    weight=(0 299 587 114)
    luma=$((luma + weight[i] * (16#$hex * 255 / ((1 << (4 * ${#hex})) - 1))))
done

if [ "$luma" -gt 128000 ]; then
    echo light
else
    echo dark
fi
