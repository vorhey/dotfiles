#!/bin/bash
case "$(cat /etc/os-release | grep '^ID=' | cut -d'=' -f2 | tr -d '"')" in
"ubuntu") echo "#[fg=red]󰕈 " ;;
"linuxmint") echo "#[fg=green]󰣭 " ;;
"debian") echo "#[fg=red] " ;;
"fedora") echo "#[fg=blue] " ;;
"arch") echo "#[fg=blue]󰣇 " ;;
"cachyos") echo "#[fg=blue]󰣇 " ;;
"pop") echo "#[fg=orange] " ;;
"opensuse-tumbleweed") echo "#[fg=green] " ;;
*) echo "" ;;
esac
