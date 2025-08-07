#!/usr/bin/env bash
# shellform.sh

set -euo pipefail
set -o errtrace

##########################################################################
# Public DSL API
##########################################################################

configure() { shellform_configure "$@"; }
end()       { shellform_end; }

##########################################################################
# Internal State and Config
##########################################################################

shellform_configuring=0
shellform_current_service=""
shellform_service_options=()
shellform_command_count=0
shellform_error_count=0
shellform_start_time=$(date +%s)
shellform_max_args=10

##########################################################################
# Logging &  rror Reporting
##########################################################################

shellform_log_dir="./logs"
mkdir -p "$shellform_log_dir"
shellform_log_file="$shellform_log_dir/shellform_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$shellform_log_file") 2>&1

shellform_fatal() {
  echo -e "\n❌ Fatal error: $*" >&2
  local i=0
  while caller $i; do ((i++)); done
  exit 1
}


shellform_exec() {
  if [[ "${shellform_dryrun:-0}" -eq 1 ]]; then
    return 0
  fi
  "$@"
}

shellform_run() {
  local cmd="$1"
  shift
  local args=("$@")
  local visible_args=("${args[@]:0:$shellform_max_args}")
  [ "${#args[@]}" -gt "$shellform_max_args" ] && visible_args+=("...")

  shellform_command_count=$((shellform_command_count + 1))
  echo -e "▶️  $cmd ${visible_args[*]}"
  if shellform_exec "$cmd" "${args[@]}"; then
    echo -e "✅ Success: $cmd ${visible_args[*]}"
  else
    echo -e "❌ Failed: $cmd ${visible_args[*]}"
    shellform_error_count=$((shellform_error_count + 1))
    return 1
  fi
}

shellform_dump_call_trace() {
  local ERROR_CMD=$(eval echo "$BASH_COMMAND")
  echo "🚨 ERROR: Command \"$ERROR_CMD\" failed."
  echo "🚨 Call trace:"
  local i=1
  while caller $i; do
    ((i++))
  done
}

##########################################################################
# Core DSL Implementation
##########################################################################

shellform_configure() {
  if [[ "$shellform_configuring" -eq 1 ]]; then
    shellform_fatal "Nested configure blocks not allowed"
  fi

  shellform_current_service="$1"
  shellform_service_options=()
  shellform_configuring=1

  local spec_func="${shellform_current_service}_spec"
  if ! declare -f "$spec_func" >/dev/null; then
    shellform_fatal "Missing required function: $spec_func"
  fi

  shellform_service_options=($($spec_func))

  for option in "${shellform_service_options[@]}"; do
    shellform_define_option_function "$option"
  done
}

shellform_define_option_function() {
  local option="$1"
  local var="shellform__${shellform_current_service}_${option}_items"
  eval "$var=()"

  eval "
  $option() {
    shellform_handle_option \"$option\" \"\$@\"
  }"
}

shellform_handle_option() {
  local option="$1"
  shift
  local var="shellform__${shellform_current_service}_${option}_items"
  local item_fn="${shellform_current_service}_${option}_item"

  eval "$var+=(\"\$@\")"

  if declare -f "$item_fn" >/dev/null; then
    "$item_fn" "$@"
  fi
}

shellform_end() {
  if [[ "$shellform_configuring" -ne 1 ]]; then
    shellform_fatal "'end' called outside of a configure block"
  fi

  for option in "${shellform_service_options[@]}"; do
    local var="shellform__${shellform_current_service}_${option}_items"
    local group_fn="${shellform_current_service}_${option}_group"
    if declare -f "$group_fn" >/dev/null && [[ "$(declare -p "$var" 2>/dev/null)" =~ "declare -a" ]]; then
      local args
      eval "args=(\"\${$var[@]}\")"
      "$group_fn" "${args[@]}"
    fi
    unset -f "$option"
    unset "$var"
  done

  shellform_configuring=0
  shellform_current_service=""
  shellform_service_options=()
}

##########################################################################
# Final Summary
##########################################################################

shellform_summary() {
  local end_time=$(date +%s)
  local elapsed=$((end_time - shellform_start_time))
  echo "\nSummary:"
  echo "  Time Elapsed: ${elapsed}s"
  echo "  Commands Run: $shellform_command_count"
  echo "  Errors:       $shellform_error_count"
  echo "  Log File:     $shellform_log_file"
}

trap shellform_dump_call_trace ERR
trap shellform_summary EXIT
