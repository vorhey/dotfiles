#!/bin/bash

# Record whether a tmux client sits on a light or dark terminal.
# Usage: tmux-theme.sh <light|dark> [client]   (default: this session's active client)
#
# Light clients are kept in @light_clients as "<name><name>"; .tmux.conf
# resolves its colours against that list per client. Both updates run inside
# the server, so hooks firing for several clients at once can't clobber each other.

client=${2:-$(tmux display-message -p '#{client_name}')}
[ -n "$client" ] || exit 1

if [ "$1" = light ]; then
    tmux set-option -gF @light_clients "#{s!<$client>!!:@light_clients}" \; \
        set-option -ga @light_clients "<$client>"
else
    tmux set-option -gF @light_clients "#{s!<$client>!!:@light_clients}"
fi
