# UV provider — minimal: venv path & Python X.Y required, PATH via ensure_shell_env

uv_spec() {
  echo "venv install"
}

uv_init() {
  if ! command -v uv >/dev/null 2>&1; then
    shellform_fatal "uv is not installed. Install it (e.g., 'brew install uv' or 'pip install uv')."
  fi
}

# Configure: both args required
# Usage: uv_venv <venv_path> <python_xy>
uv_venv() {
  local path="${1:-}"
  local py="${2:-}"   # X.Y

  [[ -n "$path" ]] || shellform_fatal "uv_venv: venv path is required"
  [[ -n "$py"   ]] || shellform_fatal "uv_venv: Python version (X.Y) is required"

  _sf_uv_path="$path"
  _sf_uv_py="$py"
}

# Ensure venv exists, no version checks, ensure PATH via ensure_shell_env
_uv_ensure_venv_min() {
  local venv_path="${_sf_uv_path}"
  local xy="${_sf_uv_py}"

  if [[ ! -d "$venv_path" ]]; then
    shellform_run uv venv --python="python${xy}" "$venv_path"
  fi

  if [[ -x "$venv_path/bin/activate" ]]; then
    ensure_shell_env PATH "$venv_path/bin"
  elif [[ -x "$venv_path/Scripts/activate" ]]; then # Windows
    ensure_shell_env PATH "$venv_path/Scripts"
  fi
}

uv_install_group() {
  _uv_ensure_venv_min
  [[ $# -gt 0 ]] || return 0
  shellform_run uv pip install "$@"
}
