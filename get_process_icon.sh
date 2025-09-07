#!/bin/bash

# Add debug logging
log_file="/tmp/tmux_icon_debug.log"
echo "Script called with argument: $1" >>"$log_file"

get_process_icon() {
    local process=$1
    echo "Processing: $process" >>"$log_file"

    case $process in
    "nvim")
        echo " "
        ;;
    "vim")
        echo " "
        ;;
    "zsh" | "bash")
        echo " "
        ;;
    "node")
        echo " "
        ;;
    "python")
        echo " "
        ;;
    "python3")
        echo " "
        ;;
    "docker")
        echo " "
        ;;
    "sh")
        echo " 󰷛"
        ;;
    "pnpm")
        echo " "
        ;;
    "npm")
        echo " "
        ;;
    "java")
        echo " "
        ;;
    "bun")
        echo " "
        ;;
    "lazygit")
        echo " "
        ;;
    "lazysql")
        echo " "
        ;;
    "spf")
        echo " 󰙅"
        ;;
    "toney")
        echo " "
        ;;
    "sam")
        echo ""
        ;;
    "gemini")
        echo " "
        ;;
    "codex")
        echo " "
        ;;
    "qwen")
        echo " 󰘯"
        ;;
    "claude")
        echo " 󰛄"
        ;;
    *)
        echo "Default case for: $process" >>"$log_file"
        echo " " # default icon
        ;;
    esac
}

get_process_icon "$1"
