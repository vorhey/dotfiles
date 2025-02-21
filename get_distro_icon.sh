#!/bin/bash
case "$(cat /etc/os-release | grep '^ID=' | cut -d'=' -f2 | tr -d '"')" in
"ubuntu") echo "#[fg=red]󰕈" ;;
"debian") echo "#[fg=red]" ;;
"fedora") echo "#[fg=blue]" ;;
"arch") echo "#[fg=blue]󰣇" ;;
"opensuse-tumbleweed") echo "#[fg=green]" ;;
*) echo "" ;;
esac
