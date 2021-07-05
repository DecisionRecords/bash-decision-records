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
# ROOT & Records
##############################

function _absolute_directory() {
  invoke "absolute_directory($1)"
  # Change to this directory
  if ! cd "$1"
  then 
    if [ "$sourced" -eq 0 ]
    then
      return 1
    else
      exit 1
    fi
  fi
  # Print the path of this directory, resolving any symlinks
  result="$(pwd -P)"
  invoke_response "absolute_directory($1)" "$result"
  echo "$result"
}

function find_root_path() {
  invoke "find_root_path()"
  if [ -z "$decision_records_root" ]
  then
    absolute_directory="$(_absolute_directory ".")"
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
        absolute_directory="$(_absolute_directory "$absolute_directory/..")"
      fi
    done

    if [ -z "$decision_records_root" ]
    then
      error "No decision records root found. Have you run \`$(basename "$0") init\`?" 1
    else
      invoke_response "find_root_path()" "$decision_records_root"
      echo "$decision_records_root"
    fi
  fi
}

function find_record_path() {
  invoke "find_record_path()"
  if [ -z "$decision_records_path" ]
  then
    this_directory="$(find_root_path)"
    if [ -f "${this_directory}/.adr-dir" ] && [ -d "${this_directory}/$(cat "${this_directory}/.adr-dir")" ]
    then
      decision_records_path="$(cat "${this_directory}/.adr-dir")"
      info "Found Decision Record path for records \`$decision_records_root\` (via .adr-dir)"
    elif [ -f "${this_directory}/.decisionrecords-config" ] && [ -d "${this_directory}/$(decision_record_config_path "${this_directory}")" ]
    then
      decision_records_path="$(decision_record_config_path "${this_directory}")"
      info "Found Decision Record path for records \`$decision_records_root\` (via .decisionrecords-config)"
    elif [ -d "${this_directory}/doc/adr" ]
    then
      decision_records_path="doc/adr"
      info "Found Decision Record path for records \`$decision_records_root\` (via default old path)"
    elif [ -d "${this_directory}/doc/decision_records" ]
    then
      decision_records_path="doc/decision_records"
      info "Found Decision Record path for records \`$decision_records_root\` (via default new path)"
    fi
  fi
  invoke_response "find_record_path()" "$decision_records_path"
  echo "$decision_records_path"
}

##############################
# Config Items
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

    info "Using config file: $config_file"
        
    config_path="doc/decision_records" # Default value
    if [ -f "$config_file" ] && grep -E '^records=' "$config_file" >/dev/null 2>&1
    then
      config_path="$(grep -E '^records=' "$config_file" | head -n 1 | cut -d= -f2)"
    else
      info "Configuration value 'records' not found in $config_file. Using the default value, \`$config_path\`."
    fi
  fi

  decision_record_config_path="$config_path"
  invoke_response "decision_record_config_path(${1-})" "$decision_record_config_path"
  echo "$decision_record_config_path"
}

# shellcheck disable=SC2120
function decision_record_config_template_dir() {
  invoke "decision_record_config_template_dir()"
  if [ -z "$decision_record_config_template_dir" ]
  then
    local config_file
    local config_path
    config_file="$(find_root_path)/.decisionrecords-config"

    config_path="$(find_record_path)/.templates" # Default value
    if [ -f "$config_file" ] && grep -E '^templatedir=' "$config_file" >/dev/null 2>&1
    then
      config_path="$(grep -E '^templatedir=' "$config_file" | head -n 1 | cut -d= -f2)"
    else
      info "Configuration value 'templatedir' not found in $config_file. Using the default value, \`$config_path\`."
    fi
  fi

  local find_root_path
  find_root_path="$(find_root_path)"

  if [ ! -e "$find_root_path/$config_path" ]
  then
    error "Template Directory \`$config_path\` is missing. Unable to proceed." 1
  else
    invoke_response "decision_record_config_template_dir()" "$config_path"
    echo "$config_path"
  fi

}

function decision_record_config_template_file() {
  invoke "decision_record_config_template_file()"
  if [ -z "$decision_record_config_template_file" ]
  then
    local config_file
    local config_path
    config_file="$(find_root_path)/.decisionrecords-config"

    config_path="template" # Default value
    if [ -f "$config_file" ] && grep -E '^template=' "$config_file" >/dev/null 2>&1
    then
      config_path="$(grep -E '^template=' "$config_file" | head -n 1 | cut -d= -f2)"
      if [ "$(grep -c -E '^template=' "$config_file")" -gt 1 ]
      then
        warning "Multiple Template configuration values detected. First value used. Please check your config file \`$config_file\` for values starting template="
      fi
    else
      info "Configuration value 'template' not found in $config_file. Using the default value, \`$config_path\`."
    fi
  fi

  local find_root_path
  local decision_record_config_template_dir
  find_root_path="$(find_root_path)"
  decision_record_config_template_dir="$(decision_record_config_template_dir)"

  if [ -n "$decision_record_config_template_dir" ]
  then
    if [ ! -e "$find_root_path/$decision_record_config_template_dir/$config_path.md" ]
    then
      error "Template \`$decision_record_config_template_dir/$config_path.md\` is missing. Unable to proceed." 1
    else
      invoke_response "decision_record_config_template_file()" "$config_path"
      echo "$config_path"
    fi
  fi
}

function decision_record_config_template_language() {
  invoke "decision_record_config_template_language()"
  if [ -z "$decision_record_config_template_language" ]
  then
    local config_file
    local config_language
    config_file="$(find_root_path)/.decisionrecords-config"

    config_language=""
    if [ -f "$config_file" ] && grep -E '^language=' "$config_file" >/dev/null 2>&1
    then
      config_language="$(grep -E '^language=' "$config_file" | head -n 1 | cut -d= -f2)"
      if [ "$(grep -c -E '^language=' "$config_file")" -gt 1 ]
      then
        warning "Multiple Template configuration values detected. First value used. Please check your config file \`$config_file\` for values starting language="
      fi
    else
      info "Configuration value 'language' not found in $config_file. Using the default value, \`$config_path\`."
    fi
  fi

  info "Using language $config_language"

  local find_root_path
  local decision_record_config_template_dir
  local decision_record_config_template_file
  find_root_path="$(find_root_path)"
  decision_record_config_template_dir="$(decision_record_config_template_dir)"
  decision_record_config_template_file="$(decision_record_config_template_file)"
  if [ -n "$decision_record_config_template_dir" ] && [ -n "$decision_record_config_template_file" ]
  then
    if [ -n "$config_language" ] && [ -e "$find_root_path/$decision_record_config_template_dir/$decision_record_config_template_file.$config_language.md" ] && [ -e "$find_root_path/$decision_record_config_template_dir/$decision_record_config_template_file.$config_language.ref" ]
    then
      invoke_response "decision_record_config_template_language()" "$config_language"
      echo "$config_language"
    elif [ -n "$config_language" ] && [ -e "$find_root_path/$decision_record_config_template_dir/$decision_record_config_template_file.$(echo "$config_language" | cut -d_ -f 1).md" ] && [ -e "$find_root_path/$decision_record_config_template_dir/$decision_record_config_template_file.$(echo "$config_language" | cut -d_ -f 1).ref" ]
    then
      invoke_response "decision_record_config_template_language()" "$(echo "$config_language" | cut -d_ -f 1)"
      echo "$config_language" | cut -d_ -f 1
    else
      invoke_response "decision_record_config_template_language()" "<none>"
      echo ""
    fi
  fi
}

##############################
# Create Items
##############################

function get_template() {
  invoke "get_template()"
  if [ -z "$decision_record_config_template_path" ]
  then
    local decision_record_config_template_dir
    local decision_record_config_template_file
    local decision_record_config_template_language
    decision_record_config_template_dir="$(decision_record_config_template_dir)"
    decision_record_config_template_file="$(decision_record_config_template_file)"
    decision_record_config_template_language="$(decision_record_config_template_language)"
  fi
}

function main() {
  find_root_path
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]
then
  sourced_off
  main
else
  unset -v decision_record_config_template_file decision_record_config_template_dir decision_record_config_path decision_records_path decision_records_root
fi
