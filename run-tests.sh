#!/usr/bin/env bash
# run-tests.sh: Executes all bats tests from the tests directory using local bats-core

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BATS_BIN="$SCRIPT_DIR/tests/test_helper/bats-core/bin/bats"

if [[ ! -x "$BATS_BIN" ]]; then
  echo "❌ bats-core not found or not executable at $BATS_BIN"
  echo "Make sure you initialized submodules:"
  echo "  git submodule update --init --recursive"
  exit 1
fi

echo "✅ Running tests with bats-core at $BATS_BIN"
echo

find "$SCRIPT_DIR/tests" -maxdepth 1 -name '*.bats' -exec "$BATS_BIN" {} +
