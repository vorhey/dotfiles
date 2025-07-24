#!/bin/bash

# Function to find project root and determine if it's a git repo
find_project_info() {

    local current_dir="$1"

    if [[ "$current_dir" == "$HOME" ]]; then
        return 0
    fi

    # Ensure we have an absolute path
    if [[ ! "$current_dir" = /* ]]; then
        current_dir="$(cd "$current_dir" 2>/dev/null && pwd)"
    fi

    # If we can't resolve the path, use current directory
    if [[ -z "$current_dir" ]]; then
        current_dir="$(pwd)"
    fi

    # First check if we're in a git repository
    local git_root
    git_root=$(cd "$current_dir" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null)

    if [[ -n "$git_root" ]]; then
        # We're in a git repo, return the git repo name
        echo " $(basename "$git_root")"
        return 0
    fi

    # Not in a git repo, look for other project indicators
    local project_files=(
        "package.json"     # Node.js
        "Cargo.toml"       # Rust
        "pyproject.toml"   # Python
        "requirements.txt" # Python
        "setup.py"         # Python
        "pom.xml"          # Java/Maven
        "build.gradle"     # Java/Gradle
        "composer.json"    # PHP
        "Gemfile"          # Ruby
        "go.mod"           # Go
        "mix.exs"          # Elixir
        "dune-project"     # OCaml
        "CMakeLists.txt"   # C/C++
        "Makefile"         # Various
        ".project"         # Eclipse
        ".vscode"          # VS Code workspace
        "pubspec.yaml"     # Flutter/Dart
        "pubspec.yml"      # Flutter/Dart (alternative spelling)
    )

    # Start from current directory and go up
    while [[ "$current_dir" != "/" && -n "$current_dir" ]]; do
        for file in "${project_files[@]}"; do
            if [[ -e "$current_dir/$file" ]]; then
                echo "󰉋 $(basename "$current_dir")"
                return 0
            fi
        done
        current_dir="$(dirname "$current_dir")"
    done

    # If no project root found, return current directory name
    echo "󰉋 $(basename "${1:-$(pwd)}")"
}

# Get the directory passed as argument or use current directory
dir="${1:-$(pwd)}"
find_project_info "$dir"
