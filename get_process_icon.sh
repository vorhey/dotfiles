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
    "zsh" | "bash" | "fish")
        echo " "
        ;;
    "tmux")
        echo " "
        ;;
    "ssh")
        echo " 󰣀"
        ;;
    "git")
        echo " "
        ;;
    "rg" | "grep" | "fzf")
        echo " "
        ;;
    "code" | "codium")
        echo " 󰨞"
        ;;
    "emacs")
        echo " "
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
    "ruby")
        echo " "
        ;;
    "php")
        echo " "
        ;;
    "go")
        echo " "
        ;;
    "rustc" | "cargo")
        echo " "
        ;;
    "deno")
        echo " "
        ;;
    "docker")
        echo " "
        ;;
    "kubectl" | "kubelet")
        echo " 󱃾"
        ;;
    "terraform")
        echo " 󱁢"
        ;;
    "psql" | "postgres")
        echo " "
        ;;
    "mysql" | "mysqld")
        echo " "
        ;;
    "redis-server")
        echo " "
        ;;
    "ffmpeg")
        echo " "
        ;;
    "sudo")
        echo " 󰒃"
        ;;
    "chrome" | "google-chrome" | "chromium")
        echo " 󰊯"
        ;;
    "firefox")
        echo " 󰈹"
        ;;
    "brave" | "brave-browser")
        echo " 󰖟"
        ;;
    "microsoft-edge" | "msedge")
        echo " 󰇩"
        ;;
    "opera")
        echo " 󰆃"
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
    "yazi")
        echo " "
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
    "copilot")
        echo " "
        ;;
    "opencode")
        echo " 󰍳"
        ;;
    *)
        echo "Default case for: $process" >>"$log_file"
        echo " " # default icon
        ;;
    esac
}

get_process_icon "$1"
