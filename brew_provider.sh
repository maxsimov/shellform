#!/usr/bin/env bash
# brew_provider.sh
# Shellform provider for Homebrew

if [[ -n "${BREW_PROVIDER_SH_INCLUDED:-}" ]]; then
  return 0
fi
BREW_PROVIDER_SH_INCLUDED=1

# Source utilities (idempotent as well)
source "${BASH_SOURCE%/*}/shellform-utils.sh"

brew_spec() {
  echo "tap install cask"
}

brew_init() {
  echo "Checking and initializing Brew..."
  ensure_path_in_zshenv /opt/homebrew/bin

  if ! command -v brew &>/dev/null; then
    echo "Homebrew not found. Installing..."
    shellform_run /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  else
    shellform_run brew update
  fi
}

brew_tap_group() {
  shellform_run brew tap "$@"
}

brew_install_group() {
  shellform_run brew install "$@"
}

brew_cask_group() {
  shellform_run brew install --cask "$@"
}

