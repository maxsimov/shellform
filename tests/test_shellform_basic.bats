#!/usr/bin/env bash

bats_require_minimum_version 1.5.0

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'
load 'test_helper/bats-mock/load'


@test "fails on unknown service spec" {
  run test_unknown_service
  assert_failure
  assert_output --partial "Missing required function: bogus_spec"
}

test_unknown_service() {
  source "${BATS_TEST_DIRNAME}/../shellform.sh"
  configure bogus
  end
}

@test "fails on nested configure blocks" {
  run test_nested_configure
  assert_failure
  assert_output --partial "Nested configure blocks not allowed"
}

test_nested_configure() {
  source "${BATS_TEST_DIRNAME}/../shellform.sh"
  dummy_spec() { echo do; }
  configure dummy
  configure again
}

@test "prints summary after execution" {
  source "${BATS_TEST_DIRNAME}/../shellform.sh"
  run test_summary
  assert_success
  assert_output --partial "Summary:"
}

test_summary() {
  source "${BATS_TEST_DIRNAME}/../shellform.sh"
  svc_spec() { echo noop; }
  svc_noop_item() {
    touch /tmp/foobar_shellform_test.txt
  }

  configure svc
    noop /tmp/foobar_shellform_test.txt
  end
  [[ -f /tmp/foobar_shellform_test.txt ]] || return 1
}

@test "calls group and item functions" {
  run test_group_and_item
  assert_success
  assert_line --index 0 "ITEM-val1"
  assert_line --index 1 "ITEM-val2"
  assert_line --index 2 "GROUP-val1 val2"
}

test_group_and_item() {
  source "${BATS_TEST_DIRNAME}/../shellform.sh"

  svc_spec() { echo opt; }
  svc_opt_item() {
    echo "ITEM-$*"
  }
  svc_opt_group() {
    echo "GROUP-$*"
  }

  configure svc
    opt val1
    opt val2
  end
}

@test "shellform_run should skip execution in dryrun mode" {
  source "${BATS_TEST_DIRNAME}/../shellform.sh"
  export shellform_dryrun=1

  # Stub command that would normally be run
  stub_command() {
    echo "This should NOT run"
    return 42
  }

  # Overwrite shellform_exec to monitor call
  shellform_exec() {
    echo "dryrun detected, skipping execution"
    return 0
  }

  run shellform_run stub_command "arg1" "arg2"

  assert_success
  assert_output --partial "▶️  stub_command arg1 arg2"
  assert_output --partial "✅ Success: stub_command arg1 arg2"
}

@test "shellform_run should run command when dryrun is not set" {
  source "${BATS_TEST_DIRNAME}/../shellform.sh"
  unset shellform_dryrun

  shellform_exec() {
    echo "actually executing: $*"
    return 0
  }

  run shellform_run echo "hello" "world"

  assert_success
  assert_output --partial "▶️  echo hello world"
  assert_output --partial "✅ Success: echo hello world"
}

@test "configure calls <service>_<option>_item for each option use and <service>_<option>_group once" {
  source "${BATS_TEST_DIRNAME}/../shellform.sh"
  # --- Arrange ---
  # Record all calls/args here
  declare -ga CALLED_ITEM=()
  declare -ga CALLED_GROUP=()

  # Service spec exposes two options: alpha and beta
  mysvc_spec() { echo "alpha beta"; }

  # Item & group handlers that record calls
  mysvc_alpha_item() {
    # Prefix with marker so we can check order/args
    CALLED_ITEM+=("alpha_item::$*")
  }
  mysvc_alpha_group() {
    CALLED_GROUP+=("alpha_group::$*")
  }

  mysvc_beta_item() {
    CALLED_ITEM+=("beta_item::$*")
  }
  mysvc_beta_group() {
    CALLED_GROUP+=("beta_group::$*")
  }

  # --- Act ---
  configure mysvc
    alpha a1
    alpha a2 a3
    beta  b1
  end

  # --- Assert ---
  # Items are called once per option use with exact args, in order
  assert_equal "${#CALLED_ITEM[@]}" "3"
  assert_equal "${CALLED_ITEM[0]}" "alpha_item::a1"
  assert_equal "${CALLED_ITEM[1]}" "alpha_item::a2 a3"
  assert_equal "${CALLED_ITEM[2]}" "beta_item::b1"

  # Groups are called once per option with all accumulated args (flattened)
  # shellform.sh passes all collected items to *_group in order
  assert_equal "${#CALLED_GROUP[@]}" "2"
  assert_equal "${CALLED_GROUP[0]}" "alpha_group::a1 a2 a3"
  assert_equal "${CALLED_GROUP[1]}" "beta_group::b1"
}

@test "option functions are unset after end (cannot call alpha/beta outside configure block)" {
  source "${BATS_TEST_DIRNAME}/../shellform.sh"
  # --- Arrange ---
  mysvc_spec() { echo "alpha beta"; }
  mysvc_alpha_item() { :; }
  mysvc_beta_item() { :; }

  # --- Act ---
  configure mysvc
    alpha x
    beta  y
  end

  # --- Assert ---
  run -127 alpha z
  assert_output --partial "alpha: command not found"

  run -127 beta z
  assert_output --partial "beta: command not found"
}

@test "<service>_init runs once per process for the same service" {
  source "${BATS_TEST_DIRNAME}/../shellform.sh"
  declare -gi INIT_COUNT=0

  svc_spec() { echo "opt"; }
  svc_init() { INIT_COUNT=$((INIT_COUNT+1)); }
  svc_opt_item() { :; }
  svc_opt_group() { :; }

  # First block
  configure svc
    opt a
  end

  # Second block — should NOT call svc_init again
  configure svc
    opt b
  end

  assert_equal "$INIT_COUNT" "1"
}

@test "<service>_init runs before any *_item" {
  source "${BATS_TEST_DIRNAME}/../shellform.sh"
  declare -ga CALLS=()

  svc_spec() { echo "pkg"; }
  svc_init() { CALLS+=("init"); }
  svc_pkg_item() { CALLS+=("item:$*"); }
  svc_pkg_group() { CALLS+=("group:$*"); }

  configure svc
    pkg x
    pkg y z
  end

  # First call must be init
  assert_equal "${CALLS[0]}" "init"
  # Items then groups (order of items preserved)
  assert_equal "${CALLS[1]}" "item:x"
  assert_equal "${CALLS[2]}" "item:y z"
  assert_equal "${CALLS[3]}" "group:x y z"
}

@test "different services each run their own _init once" {
  source "${BATS_TEST_DIRNAME}/../shellform.sh"
  declare -gi INIT_S1=0 INIT_S2=0

  s1_spec() { echo "o"; }
  s1_init() { INIT_S1=$((INIT_S1+1)); }
  s1_o_item() { :; }
  s1_o_group() { :; }

  s2_spec() { echo "o"; }
  s2_init() { INIT_S2=$((INIT_S2+1)); }
  s2_o_item() { :; }
  s2_o_group() { :; }

  configure s1
    o a
  end
  configure s2
    o b
  end
  configure s1
    o c
  end

  assert_equal "$INIT_S1" "1"
  assert_equal "$INIT_S2" "1"
}

@test "inited guard variable is created and set to 1" {
  source "${BATS_TEST_DIRNAME}/../shellform.sh"
  svc_spec() { echo "k"; }
  svc_init() { :; }
  svc_k_item() { :; }
  svc_k_group() { :; }

  configure svc
    k abc
  end

  # Guard variable should be set: shellform_service_svc_inited=1
  local guard_var="shellform_service_svc_inited"
  # Indirect expansion to read the dynamically named variable
  assert [ "${!guard_var}" -eq 1 ]
}
