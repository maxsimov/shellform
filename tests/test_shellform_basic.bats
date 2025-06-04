#!/usr/bin/env bash

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

@test "fails on unknown service spec" {
  run test_unknown_service
  assert_failure
  assert_output --partial "Missing required function: bogus_spec"
}

test_unknown_service() {
  source "$BATS_TEST_DIRNAME/../shellform.sh"
  configure bogus
  end
}

@test "fails on nested configure blocks" {
  run test_nested_configure
  assert_failure
  assert_output --partial "Nested configure blocks not allowed"
}

test_nested_configure() {
  source "$BATS_TEST_DIRNAME/../shellform.sh"
  dummy_spec() { echo do; }
  configure dummy
  configure again
}

@test "prints summary after execution" {
  run test_summary
  assert_success
  assert_output --partial "Summary:"
}

test_summary() {
  source "$BATS_TEST_DIRNAME/../shellform.sh"

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
  assert_output --partial "ITEM-val1 val2"
  assert_output --partial "GROUP-val1 val2"
}

test_group_and_item() {
  source "$BATS_TEST_DIRNAME/../shellform.sh"

  svc_spec() { echo opt; }
  svc_opt_item() { echo "ITEM-$*"; }
  svc_opt_group() { echo "GROUP-$*"; }

  configure svc
    opt val1 val2
  end
}
