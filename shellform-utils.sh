#!/usr/bin/env bash
# shellform-utils.sh
# Utility functions for managing shell environment and config files.
# Supports macOS and Linux.

[ -n "${SHELLFORM_UTILS_LOADED:-}" ] && return 0
SHELLFORM_UTILS_LOADED=1

# ─── Init Function ───────────────────────────────────────────────────────
init_shellform_utils() {
    case "$(uname -s)" in
        Darwin)
            SHELLFORM_UTILS_OS="macos"
            ;;
        Linux)
            SHELLFORM_UTILS_OS="linux"
            ;;
        *)
            SHELLFORM_UTILS_OS="unknown"
            ;;
    esac
}

# ─── Functions ───────────────────────────────────────────────────────────
ensure_path_in_zshenv() {
    local path_to_add="${1}"
    local zshenv_file="$HOME/.zshenv"
    local path_export="export PATH=\"$path_to_add:\$PATH\""

    touch "$zshenv_file"

    if grep -Fxq "$path_export" "$zshenv_file"; then
        echo "✅ Path '$path_to_add' is already in ~/.zshenv"
    else
        echo "➕ Adding '$path_to_add' to ~/.zshenv"
        echo "$path_export" >> "$zshenv_file"
        # shellcheck disable=SC1090
        source "$zshenv_file"
        echo "✅ Path added and ~/.zshenv reloaded."
    fi
}

ensure_path_in_shell_rc() {
    local path_to_add="${1}"
    local file
    file="$(get_shell_rc_file)"
    local path_export="export PATH=\"$path_to_add:\$PATH\""

    touch "$file"

    if grep -Fxq "$path_export" "$file"; then
        echo "✅ Path '$path_to_add' is already in $file"
    else
        echo "➕ Adding '$path_to_add' to $file"
        echo "$path_export" >> "$file"
        # shellcheck disable=SC1090
        source "$file"
        echo "✅ Path added and $file reloaded."
    fi
}

ensure_shell_env() {
    local var_name="$1"
    local var_value="$2"
    shift 2

    local file
    file="$(get_shell_rc_file)"

    touch "$file"

    local export_line="export $var_name=$var_value"

    if grep -q "^export $var_name=" "$file"; then
        sed -i.bak "s|^export $var_name=.*$|$export_line|" "$file"
        echo "✅ Updated $var_name in $file"
    else
        echo "$export_line" >> "$file"
        echo "✅ Added $var_name to $file"
    fi

    # shellcheck disable=SC1090
    source "$file"
}

ensure_shell_command() {
    local command="$*"
    local file
    file="$(get_shell_rc_file)"

    touch "$file"

    if grep -Fxq "$command" "$file"; then
        echo "✅ Command \"$command\" already exists in $file"
    else
        echo "$command" >> "$file"
        echo "✅ Added command to $file"
    fi

    # shellcheck disable=SC1090
    source "$file"
}

get_shell_rc_file() {
    local shell_rc_file=""

    case "$SHELLFORM_UTILS_OS" in
        macos)
            shell_rc_file="$HOME/.zshrc"
            ;;
        linux)
            if [ -n "$BASH_VERSION" ]; then
                shell_rc_file="$HOME/.bashrc"
            elif [ -n "$ZSH_VERSION" ]; then
                shell_rc_file="$HOME/.zshrc"
            else
                shell_rc_file="$HOME/.bashrc"
            fi
            ;;
        *)
            shell_rc_file="$HOME/.bashrc"
            ;;
    esac

    echo "$shell_rc_file"
}

# ─── Initialize on Source ────────────────────────────────────────────────
init_shellform_utils
