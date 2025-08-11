#!/usr/bin/env bats

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

PROVIDER_FILE="uv_provider.sh"

setup() {
  TMPROOT="$(mktemp -d)"
  TMPBIN="$TMPROOT/bin"
  mkdir -p "$TMPBIN"

  # Sandboxed PATH: our bin + core utils only (no Homebrew/asdf)
  export PATH="$TMPBIN:/usr/bin:/bin"

  # Source provider first, then override fatal for assertions
  # shellcheck source=/dev/null
  source "$PROVIDER_FILE"
  shellform_fatal() { echo "FATAL:$*"; exit 1; }
}

teardown() {
  rm -rf "$TMPROOT"
}

_make_fake_exec() {
  local name="$1"; shift
  {
    echo '#!/usr/bin/env bash'
    printf '%s\n' "$@"
  } >"$TMPBIN/$name"
  chmod +x "$TMPBIN/$name"
}

# ── A. Basics ────────────────────────────────────────────────────────────────

@test "uv_spec outputs verbs" {
  run uv_spec
  assert_success
  assert_output "venv install"
}

@test "uv_init fails when uv is missing" {
  # With our PATH, uv is not present
  run uv_init
  assert_failure
  assert_output --partial "uv is not installed"
}

@test "uv_init passes when uv is present" {
  _make_fake_exec uv 'exit 0'
  run uv_init
  assert_success
}
