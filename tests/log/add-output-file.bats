#! /usr/bin/env bats

load ../environment
load helpers

teardown() {
  remove_test_go_rootdir
}

run_log_script_and_assert_status_and_output() {
  set +o functrace
  local num_errors

  run_log_script "$@" \
    '@go.log INFO  FYI' \
    '@go.log RUN   echo foo' \
    '@go.log WARN  watch out' \
    '@go.log ERROR uh-oh' \
    '@go.log FATAL oh noes!'

  if ! assert_failure; then
    set +o functrace
    return_from_bats_assertion "$BASH_SOURCE" 1
    return
  fi

  local expected=(INFO 'FYI'
    RUN   'echo foo'
    WARN  'watch out'
    ERROR 'uh-oh'
    FATAL 'oh noes!'
    "$(test_script_stack_trace_item)")

  if ! assert_log_equals "${expected[@]}"; then
    set +o functrace
    return_from_bats_assertion "$BASH_SOURCE" 1
  else
    return_from_bats_assertion "$BASH_SOURCE"
  fi
}

@test "$SUITE: add an output file for all log levels" {
  run_log_script_and_assert_status_and_output \
    "@go.log_add_output_file '$TEST_GO_ROOTDIR/all.log'"
  assert_equal "$output" "$(< "$TEST_GO_ROOTDIR/all.log")" 'all.log'
}

@test "$SUITE: add an output file for an existing log level" {
  run_log_script_and_assert_status_and_output \
    "@go.log_add_output_file '$TEST_GO_ROOTDIR/info.log' 'INFO'"
  assert_matches "^INFO +FYI$" "$(< "$TEST_GO_ROOTDIR/info.log")" 'info.log'
}

@test "$SUITE: force formatted output in log file" {
  _GO_LOG_FORMATTING='true' run_log_script \
    "@go.log_add_output_file '$TEST_GO_ROOTDIR/info.log' 'INFO'" \
    "@go.log INFO Hello, World!"
  assert_success
  assert_log_equals "$(format_label INFO)" 'Hello, World!'
  assert_equal "$output" "$(< "$TEST_GO_ROOTDIR/info.log")" 'info.log'
}

@test "$SUITE: add an output file for a new log level" {
  local msg="This shouldn't appear in standard output or error."

  # Note that FOOBAR has the same number of characters as FINISH, currently the
  # longest log label name. If FINISH is ever removed without another
  # six-character label taking its place, the test may fail because of changes
  # in label padding. The fix would be to replace FOOBAR with a new name no
  # longer than the longest built-in log label.
  run_log_script_and_assert_status_and_output \
    "@go.log_add_output_file '$TEST_GO_ROOTDIR/foobar.log' 'FOOBAR'" \
    "@go.log FOOBAR \"$msg\""

  assert_matches "^FOOBAR +$msg$" \
    "$(< "$TEST_GO_ROOTDIR/foobar.log")" 'foobar.log'
}

@test "$SUITE: add output files for multiple log levels" {
  run_log_script_and_assert_status_and_output \
    "@go.log_add_output_file '$TEST_GO_ROOTDIR/error.log' 'ERROR,FATAL'"

  local IFS=$'\n'
  local error_log=($(< "$TEST_GO_ROOTDIR/error.log"))

  assert_equal '3' "${#error_log[@]}" 'Number of error log lines'
  assert_matches '^ERROR +uh-oh$' "${error_log[0]}" 'ERROR log message'
  assert_matches '^FATAL +oh noes!$' "${error_log[1]}" 'FATAL log message'
  assert_equal "$(test_script_stack_trace_item)" "${error_log[2]}" \
    'FATAL stack trace'
}

@test "$SUITE: add output files for a mix of levels" {
  local msg="This shouldn't appear in standard output or error."

  # Same note regarding FOOBAR from the earlier test case applies.
  run_log_script_and_assert_status_and_output \
    "@go.log_add_output_file '$TEST_GO_ROOTDIR/info.log' 'INFO'" \
    "@go.log_add_output_file '$TEST_GO_ROOTDIR/all.log'" \
    "@go.log_add_output_file '$TEST_GO_ROOTDIR/error.log' 'ERROR,FATAL'" \
    "@go.log_add_output_file '$TEST_GO_ROOTDIR/foobar.log' 'FOOBAR'" \
    "@go.log FOOBAR \"$msg\""

  assert_equal "$output" "$(< "$TEST_GO_ROOTDIR/all.log")" 'all.log'
  assert_matches "^INFO +FYI$" "$(< "$TEST_GO_ROOTDIR/info.log")" 'info.log'
  assert_matches "^FOOBAR +$msg$" \
    "$(< "$TEST_GO_ROOTDIR/foobar.log")" 'foobar.log'

  local IFS=$'\n'
  local error_log=($(< "$TEST_GO_ROOTDIR/error.log"))

  assert_equal '3' "${#error_log[@]}" 'Number of error log lines'
  assert_matches '^ERROR +uh-oh$' "${error_log[0]}" 'ERROR log message'
  assert_matches '^FATAL +oh noes!$' "${error_log[1]}" 'FATAL log message'
  assert_equal "$(test_script_stack_trace_item)" "${error_log[2]}" \
    'FATAL stack trace'
}
