#!/usr/bin/env bash
# files_provider.sh — copy or symlink tracked files into system paths when changed

files_spec() { echo "copy link mirror"; }

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

# Immediate action for each link item — symlink dest -> src (replaces any
# existing file/symlink). Unlike copy, edits to dest write through to the
# tracked src, so the file stays in sync with the repo.
files_link_item() {
  local src_raw="$1"
  local dest_raw="$2"

  if [[ -z "${src_raw:-}" || -z "${dest_raw:-}" ]]; then
    shellform_fatal "link requires: link <src> <dest>"
    return 1
  fi

  local src="$(_files_resolve_src "$src_raw")"
  local dest="$(_files_resolve_dest "$dest_raw")"

  # validate source (file or dir)
  if [[ ! -e "$src" ]]; then
    shellform_fatal "source not found: $src"
    return 1
  fi

  # create destination directory
  local parent
  parent="$(dirname -- "$dest")"
  shellform_run mkdir -p -- "$parent"

  # link only if needed
  if [[ -L "$dest" && "$(readlink -- "$dest")" == "$src" ]]; then
    echo "OK      $dest (no change)"
  else
    shellform_run ln -sfn -- "$src" "$dest"
    echo "UPDATED $dest -> $src"
  fi
}

# mirror <tracked-glob> <live-glob> — keep a *dynamic set* of live paths symlinked
# to a tracked (repo) store, gluing sets that the static `link` verb can't
# enumerate. Each glob takes a single '*' that maps positionally between the two:
#   - for every tracked path matching <tracked-glob>: ensure the corresponding
#     live path is a symlink to it (creating parents) — restores links on a fresh
#     machine and for every current/future entry.
#   - for every live path matching <live-glob> that is a *real* dir (not a
#     symlink): adopt it into the store (move) then symlink back — captures new
#     entries automatically.
# A live real dir whose tracked counterpart already exists is left untouched with
# a warning (ambiguous) rather than risk clobbering either side.
files_mirror_item() {
  local tracked_glob="$1" live_glob="$2"

  if [[ -z "${tracked_glob:-}" || -z "${live_glob:-}" ]]; then
    shellform_fatal "mirror requires: mirror <tracked-glob> <live-glob>"
    return 1
  fi

  tracked_glob="$(_files_expand "$tracked_glob")"
  live_glob="$(_files_expand "$live_glob")"

  local t_pre="${tracked_glob%%\**}" t_suf="${tracked_glob#*\*}"
  local l_pre="${live_glob%%\**}"    l_suf="${live_glob#*\*}"

  # 1. Adopt new live real dirs into the store, then symlink back.
  local live star tracked
  for live in $live_glob; do
    [[ -e "$live" ]] || continue          # glob didn't match
    [[ -L "$live" ]] && continue          # already a symlink
    star="${live#"$l_pre"}"; star="${star%"$l_suf"}"
    tracked="${t_pre}${star}${t_suf}"
    if [[ -e "$tracked" ]]; then
      echo "WARN    $live (real) and $tracked both exist — resolve by hand" >&2
      continue
    fi
    shellform_run mkdir -p -- "$(dirname -- "$tracked")"
    shellform_run mv -- "$live" "$tracked"
    shellform_run ln -sfn -- "$tracked" "$live"
    echo "ADOPTED $live -> $tracked"
  done

  # 2. Ensure every tracked entry has its live symlink (fresh machine / new).
  local live2 star2
  for tracked in $tracked_glob; do
    [[ -e "$tracked" ]] || continue
    star2="${tracked#"$t_pre"}"; star2="${star2%"$t_suf"}"
    live2="${l_pre}${star2}${l_suf}"
    if [[ -L "$live2" && "$(readlink -- "$live2")" == "$tracked" ]]; then
      echo "OK      $live2 (no change)"
      continue
    fi
    if [[ -e "$live2" && ! -L "$live2" ]]; then
      continue  # real dir/file — conflict already warned above
    fi
    shellform_run mkdir -p -- "$(dirname -- "$live2")"
    shellform_run ln -sfn -- "$tracked" "$live2"
    echo "LINKED  $live2 -> $tracked"
  done
}

