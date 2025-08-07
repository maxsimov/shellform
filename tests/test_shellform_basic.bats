#!/usr/bin/env bash

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

