#!/usr/bin/env bash
# files_provider.sh — copy tracked files into system paths when changed

files_spec() { echo "copy"; }

# Expand ~ to $HOME
_files_expand() {
  local p="$1"
  case "$p" in
    "~")  printf '%s\n' "$HOME" ;;
    "~/"*) printf '%s\n' "$HOME/${p#\~/}" ;;
    *)     printf '%s\n' "$p" ;;
  esac
}

# Resolve src relative to $SHELLFORM_FILES_BASE (default: $PWD)
_files_resolve_src() {
  local raw="$1"
  local base="${SHELLFORM_FILES_BASE:-$PWD}"
  local p; p="$(_files_expand "$raw")"
  [[ "$p" = /* ]] || p="$base/$p"
  printf '%s\n' "$p"
}

# Resolve dest to absolute path
_files_resolve_dest() {
  local raw="$1"
  local p; p="$(_files_expand "$raw")"
  [[ "$p" = /* ]] || p="$PWD/$p"
  printf '%s\n' "$p"
}

# Compare two files
_files_same() {
  local a="$1" b="$2"
  [[ -f "$a" && -f "$b" ]] && cmp -s -- "$a" "$b"
}

# Immediate action for each copy item
files_copy_item() {
  local src_raw="$1"
  local dest_raw="$2"

  if [[ -z "${src_raw:-}" || -z "${dest_raw:-}" ]]; then
    shellform_fatal "copy requires: copy <src> <dest>"
    return 1
  fi

  local src="$(_files_resolve_src "$src_raw")"
  local dest="$(_files_resolve_dest "$dest_raw")"

  # validate source file
  if [[ ! -f "$src" ]]; then
    shellform_fatal "source not found: $src"
    return 1
  fi

  # create destination directory
  local parent
  parent="$(dirname -- "$dest")"
  shellform_run mkdir -p -- "$parent"

  # copy only if needed
  if _files_same "$src" "$dest"; then
    echo "OK      $dest (no change)"
  else
    shellform_run cp -f -- "$src" "$dest"
    echo "UPDATED $dest"
  fi
}

