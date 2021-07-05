#!/bin/bash
##############################
# MESSAGING
##############################
sourced=0

function sourced_on() {
  sourced=1
}

function sourced_off() {
  sourced=0
}

# The functions "setup_colours" and "msg" from "Minimal safe Bash script template"
# https://betterdev.blog/minimal-safe-bash-script-template/
# shellcheck disable=SC2034 # Unused variables left for later use.
function setup_colors() {
  if [[ -t 2 ]] && [[ -z "${NO_COLOR-}" ]] && [[ "${TERM-}" != "dumb" ]]; then
    NOFORMAT='\033[0m' RED='\033[0;31m' GREEN='\033[0;32m' ORANGE='\033[0;33m' BLUE='\033[0;34m' PURPLE='\033[0;35m' CYAN='\033[0;36m' YELLOW='\033[1;33m'
  else
    NOFORMAT='' RED='' GREEN='' ORANGE='' BLUE='' PURPLE='' CYAN='' YELLOW=''
  fi
}

# Output goes to STDERR unless explicitly directed to STDOUT
function msg() {
  echo >&2 -e "${1-}"
}

function invoke() {
  if [ "${LOG_LEVEL-0}" -ge 8 ]
  then
    msg "${ORANGE}[ Invoke]($1): start${NOFORMAT}"
  fi
}

function invoke_response() {
  if [ "${LOG_LEVEL-0}" -ge 4 ]
  then
    msg "${ORANGE}[ Invoke]($1): exit: $2 ${NOFORMAT}"
  fi
}

function debug() {
  if [ "${LOG_LEVEL-0}" -ge 2 ]
  then
    msg "${CYAN}[ DEBUG ]: $1${NOFORMAT}"
  fi
}

function info() {
  if [ "${LOG_LEVEL-0}" -ge 1 ]
  then
    msg "${BLUE}[ INFO  ]: $1${NOFORMAT}"
  fi
}

function warning() {
    msg "${PURPLE}[Warning]: $1${NOFORMAT}"
}

function error() {
  msg "${RED}[ Error ]: $1${NOFORMAT}"
  if [ "${2-0}" -gt 0 ]
  then
    if [ "$sourced" -eq 0 ]
    then
      return "${2-0}"
    else
      exit "${2-0}"
    fi
  fi
}

##############################
# ROOT
##############################

function decision_record_config_path() {
  invoke "decision_record_config_path(${1-})"
  if [ -z "$decision_record_config_path" ]
  then
    local config_file
    local config_path
    if [ -n "${1-}" ]
    then
      config_file="$1/.decisionrecords-config"
    else
      config_file="$(find_root_path)/.decisionrecords-config"
    fi

    config_path="doc/decision_records" # Default value
    if grep -E '^records=' "$config_file" >/dev/null
    then
      config_path="$(grep -E '^records=' "$config_file" | cut -d= -f2)"
    fi
  fi

  invoke_response "decision_record_config_path(${1-})" "$config_path"
  echo "$config_path"
}

function find_root_path() {
  invoke "find_root_path()"
  if [ -z "$decision_records_root" ]
  then
    this_directory="."
    absolute_directory="$(absolute_directory "$this_directory")"
    while [ "$absolute_directory" != "/" ] && [ -z "$decision_records_root" ]
    do
      if [ -f "${absolute_directory}/.adr-dir" ] && [ -d "${absolute_directory}/$(cat "${absolute_directory}/.adr-dir")" ]
      then
        decision_records_root="${absolute_directory}"
        info "Found Decision Record root path \`$decision_records_root\` (via .adr-dir)"
      elif [ -f "${absolute_directory}/.decisionrecords-config" ] && [ -d "${absolute_directory}/$(decision_record_config_path "${absolute_directory}")" ]
      then
        decision_records_root="${absolute_directory}"
        info "Found Decision Record root path \`$decision_records_root\` (via .decisionrecords-config)"
      elif [ -d "${absolute_directory}/doc/adr" ]
      then
        decision_records_root="${absolute_directory}"
        info "Found Decision Record root path \`$decision_records_root\` (via default old path)"
      elif [ -d "${absolute_directory}/doc/decision_records" ]
      then
        decision_records_root="${absolute_directory}"
        info "Found Decision Record root path \`$decision_records_root\` (via default new path)"
      else
        debug "Not found in this path, going up!"
        this_directory="../$this_directory"
        absolute_directory="$(absolute_directory "$this_directory")"
      fi
    done

    if [ -z "$decision_records_root" ]
    then
      error "No decision records root found. Have you run \`$0 init\`?" 1
    else
      invoke_response "find_root_path()" "$decision_records_root"
      echo "$decision_records_root"
    fi
  fi
}

function absolute_directory() {
  invoke "absolute_directory($1)"
  # Change to this directory
  cd "$(dirname "$1")" || return
  # Print the path of this directory, resolving any symlinks
  result="$(pwd -P)"
  invoke_response "absolute_directory($1)" "$result"
  echo "$result"
}

function main() {
  find_root_path
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]
then
  sourced_off
  main
fi
