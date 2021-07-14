#!/bin/bash

set -eo pipefail

###################################################################################################
# License: Zero-Clause BSD (0BSD)
# Permission to use, copy, modify, and/or distribute this software for any purpose with or without
# fee is hereby granted.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS
# SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE
# AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT,
# NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE
# OF THIS SOFTWARE.
###################################################################################################

###################################################################################################
# # Purpose of this script
#
# This script is intended to automate the process of adding and updating Decision Records (DR),
# sometimes known as "Architectural Decision Records" (ADR). A DR is a simple file which explains
# why a decision was made at a particular time, the context in which that decision was made, and
# what implications it may have. These files reside in a specific directory, and have a specific
# naming structure. Linking between documents is recommended, and replacing documents should be
# fairly commonplace.
#
# ## Running the script
#
# You are expected to run `decision-record.sh init` to create a directory structure, then
# `decision-record.sh new Decision to use foo` which will create a file called
# `doc/decision_records/0001-decision-to-use-foo.md` which produces a specific template. You may
# choose to then run `decision-record.sh new --supersede 1 Decision to use bar instead of foo`
# which will create the file `doc/decision_records/0002-decision-to-use-bar-instead-of-foo.md`
# which has a link showing that this record supersedes the previous record.
#
# Additional options will be available in the help, found when you run `decision-record.sh help`.
###################################################################################################
# ## Language support and file paths
#
# There is a configuration file format you can use in any root directory, similar in concept to the
# .gitconfig or .vscode file, which is called `.decisionrecords-config`. This file can replace
# default paths for:
#
# * The records directory:
#   * Default `doc/decision_records`
#   * Configure `records=new relative path` to change to "new relative path"
# * The path to the templates:
#   * Default `$(records)/.templates`
#   * Configure `templatedir=relative/path/to/template directory` to change it to this new path
# * The type of template file we can use:
#   * Default `md`
#   * Configure `filetype=rst` to change to Restructured Text.
#   * Options: Currently, only `rst` and `md` are supported. If other templates are available,
#       please raise a PR to support them!
# * The name of the template file to use:
#   * Default `template`
#   * Configure `template=decision record template` to change the file prefix (excluding language
#       and format) to this new path.
# * The language of the template and string replacements to use:
#  * Default `en`
#  * Configure `language=zh-CN` to use Chinese with Simplified Characters, `language=de_DE` to use
#              "Standard German", or `language=fr` to use French with no country localization.
#  * Notes: This language field should be represented using the ISO-639-1 code for the langauge,
#      e.g. `en`, then if a dialect is to be selected, add an underscore or hyphen then the
#      dialect code, using the ISO-3166-1 Alpha 2 code for the country, e.g. `GB`. For more
#      examples, see [the wikipedia page on Language
#      Localisation](https://en.wikipedia.org/wiki/Language_localisation).  This configuration
#      relies on the provision of relevant template and translation strings. If a language is
#      defined, but not available, the script will fall-back to English.
###################################################################################################
# ## Templates
#
# The template file should be stored, according to the language block just mentioned, and needs to
# have some key strings stored for exchange. These values are:
#
# * `NUMBER`: This string is replaced with the integer value of the record, e.g. 1, 57 or 999
# * `TITLE`: This is the string provided as the title of the new record.
# * `DATE`: This is the date that the DR was created, and is stored in a YYYY-MM-DD format.
# * `STATUS`: This is the INITIAL value of the status, which defaults to "Approved", but can
#    be overriden with `decision-record.sh new -P Some Title` to create a "Proposed record"
#    with the title "Some Title", or `decision-record.sh new -S WIP Some Title` to create a
#    decision record with a status of "WIP" and a title of "Some Title".
#
# When the titles are parsed (when a record is superseded, linked, amended or deprecated), the
# record will be parsed looking for the first of the following values:
#
# * A string matching the regular expression `^\s*# [0-9]+\. .*$`
# * A string matching the regular expression `^\s*title=.*$`
#
# This will be injected into the link text whenever a record link is performed.
###################################################################################################

# Translate Functions
# shellcheck disable=SC2005 # @TODO: See if we can figure out how to do `echo "" | cut` without using `echo`... :)
function _tt() {
  invoke "_tt(string='$1')"
  invoke_response "_tt(string='$1')" "<INLINE>"

  if [ -z "$decision_record_config_template_reference" ]
  then
    if [ -z "$decision_record_config_template_dir" ]
    then
      decision_record_config_template_dir
    fi

    if [ -z "$decision_record_config_template_file" ]
    then
      decision_record_config_template_file
    fi

    if [ -z "$decision_record_config_template_language" ]
    then
      decision_record_config_template_language
    fi
    
    if [ -z "$decision_record_config_template_language" ]
    then
      decision_record_config_template_reference="$decision_record_config_template_dir/$decision_record_config_template_file.ref"
    else
      decision_record_config_template_reference="$decision_record_config_template_dir/$decision_record_config_template_file.$decision_record_config_template_language.ref"
    fi
  fi

  if [ -z "$decision_record_root" ]
  then
    decision_record_root
  fi

  if [ -e "$decision_record_root/$decision_record_config_template_reference" ]
  then
    stringline="$(grep -E "^$1=" "$decision_record_root/$decision_record_config_template_reference")"
    if [ -n "$stringline" ]
    then
      quotecheck="$(echo "$stringline" | cut -d= -f2)"
      if [[ "$quotecheck" =~ \".*\"$ ]]
      then
        echo "$(echo "$quotecheck" | cut -d\" -f2)"
      else
        echo "$quotecheck"
      fi
    else
      echo "$1"
    fi
  else
    echo "$1"
  fi
}

function _t() {
  invoke "_t(string='$1')"
  invoke_response "_t(string='$1')" "<INLINE>"
  
  if [ -z "$decision_record_language" ]
  then
    decision_record_language
  fi
  
  if [[ "$decision_record_language" =~ de* ]]
  then
    case "$1" in
      'Accepted') echo "Akzeptiert" ; return ;;
      'Proposed') echo "Vorgeschlagen" ; return ;;
      'Superseded by #') echo "Ersetzt durch #" ; return ;;
      'Supersedes #') echo "Ersetzt #" ; return ;;
      'Amends #') echo "Ändert #" ; return ;;
      'Amended by #') echo "Geändert von #" ; return ;;
      'Deprecates #') echo "Veraltet #" ; return ;;
      'Deprecated by #') echo "Veraltet von #" ; return ;;
      'Linked with #') echo "Verknüpft mit #" ; return ;;
    esac
  elif [[ "$decision_record_language" =~ fr* ]]
  then
    case "$1" in
      'Accepted') echo "Accepté" ; return ;;
      'Proposed') echo "Proposé" ; return ;;
      'Superseded by #') echo "Remplacé par #" ; return ;;
      'Supersedes #') echo "Remplace #" ; return ;;
      'Amends #') echo "Modifie #" ; return ;;
      'Amended by #') echo "Modifié par #" ; return ;;
      'Deprecates #') echo "Obsolète #" ; return ;;
      'Deprecated by #') echo "Obsolète par #" ; return ;;
      'Linked with #') echo "Liée à #" ; return ;;
    esac
  elif [[ "$decision_record_language" =~ jp* ]]
  then
    case "$1" in
      'Accepted') echo "承認された" ; return ;;
      'Proposed') echo "提案された" ; return ;;
      'Superseded by #') echo "#に置き換えられました" ; return ;;
      'Supersedes #') echo "#を置き換える" ; return ;;
      'Amends #') echo "#を修正" ; return ;;
      'Amended by #') echo "#によって修正されました" ; return ;;
      'Deprecates #') echo "#を非推奨" ; return ;;
      'Deprecated by #') echo "#によって廃止予定" ; return ;;
      'Linked with #') echo "#とリンク" ; return ;;
    esac
  fi
  echo "$1"
}

function _get_decision_record_language() {
  decision_record_language
  echo "$decision_record_language"
}

function decision_record_language() {
  invoke "decision_record_language()"
  if [ -z "$decision_record_language" ]
  then
    if [ -z "$decision_record_root" ]
    then
      decision_record_root
    fi
    local config_file
    config_file="$decision_record_root/.decisionrecords-config"

    decision_record_language=""
    if [ -f "$config_file" ] 
    then
      if grep -E -e '^language=' "$config_file" >/dev/null 2>&1
      then
        decision_record_language="$(grep -E -e '^language=' "$config_file" | head -n 1 | cut -d= -f2)"
        if [ "$(grep -c -E -e '^language=' "$config_file")" -gt 1 ]
        then
          warning "Multiple Template configuration values detected. First value used. Please check your config file \`$config_file\` for values starting language="
        fi
      else
        info "Configuration value 'language' not found in $config_file. Using the default value, \`$decision_record_language\`."
      fi
    else
      info "Config file not found. Using the default value, \`$decision_record_language\`."
    fi
  fi

  invoke_response "decision_record_language()" "$decision_record_language"
}

##############################
# MESSAGING
##############################

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
  if [ -n "$DEPTH" ]
  then
    DEPTH="$DEPTH>"
  fi
  DEPTH="$DEPTH$1"
  if [ "${LOG_LEVEL-0}" -ge 8 ]
  then
    msg "${ORANGE}[Invoke ]<$DEPTH>: start${NOFORMAT}"
    msg ""
  fi
}

function invoke_response() {
  if [ "${LOG_LEVEL-0}" -ge 4 ]
  then
    msg ""
    msg "${ORANGE}[Respond]: $2 ${NOFORMAT}"
    msg "${ORANGE}[InvokeR]<$DEPTH>: exit: ${NOFORMAT}"
    msg ""
  fi
  IFS=">" read -r -a DEPTHITEM <<< "$DEPTH"
  DEPTH=""
  LASTITEM=""
  for ITEM in "${DEPTHITEM[@]}"
  do
    if [ -n "$DEPTH" ]
    then
      DEPTH="$DEPTH>"
    fi
    DEPTH="${DEPTH}${LASTITEM}"
    LASTITEM="$ITEM"
  done
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
    exit "${2-0}"
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
    return 1
  fi
  # Print the path of this directory, resolving any symlinks
  result="$(pwd -P)"
  invoke_response "absolute_directory($1)" "$result"
  echo "$result"
}

function _get_decision_record_root() {
  decision_record_root
  echo "$decision_record_root"
}

function decision_record_root() {
  invoke "decision_record_root()"
  if [ -z "$decision_record_root" ]
  then
    absolute_directory="$(_absolute_directory ".")"
    while [ "$absolute_directory" != "/" ] && [ -z "$decision_record_root" ]
    do
      if [ -f "${absolute_directory}/.adr-dir" ] && [ -d "${absolute_directory}/$(cat "${absolute_directory}/.adr-dir")" ]
      then
        decision_record_root="${absolute_directory}"
        info "Found Decision Record root path \`$decision_record_root\` (via .adr-dir)"
      elif [ -f "${absolute_directory}/.decisionrecords-config" ] && [ -d "${absolute_directory}/$(_get_decision_record_config_path "${absolute_directory}")" ]
      then
        decision_record_root="${absolute_directory}"
        info "Found Decision Record root path \`$decision_record_root\` (via .decisionrecords-config)"
      elif [ -d "${absolute_directory}/doc/adr" ]
      then
        decision_record_root="${absolute_directory}"
        info "Found Decision Record root path \`$decision_record_root\` (via default old path)"
      elif [ -d "${absolute_directory}/doc/decision_records" ]
      then
        decision_record_root="${absolute_directory}"
        info "Found Decision Record root path \`$decision_record_root\` (via default new path)"
      else
        debug "Not found in this path, going up!"
        absolute_directory="$(_absolute_directory "$absolute_directory/..")"
      fi
    done
  fi

  if [ -z "$decision_record_root" ]
  then
    error "No decision records root found. Have you run \`$(basename "$0") init\`?"
    exit 1
  else
    invoke_response "decision_record_root()" "$decision_record_root"
  fi
}

function _get_decision_record_path() {
  decision_record_path
  echo "$decision_record_path"
}

function decision_record_path() {
  invoke "decision_record_path()"
  if [ -z "$decision_record_path" ]
  then
    if [ -z "$decision_record_root" ]
    then
      decision_record_root
    fi
    this_directory="$decision_record_root"
    if [ -f "${this_directory}/.adr-dir" ] && [ -d "${this_directory}/$(cat "${this_directory}/.adr-dir")" ]
    then
      decision_record_path="$(cat "${this_directory}/.adr-dir")"
      info "Found Decision Record path for records \`$decision_record_path\` (via .adr-dir)"
    elif [ -f "${this_directory}/.decisionrecords-config" ] && [ -d "${this_directory}/$(_get_decision_record_config_path "${this_directory}")" ]
    then
      decision_record_path="$(_get_decision_record_config_path "${this_directory}")"
      info "Found Decision Record path for records \`$decision_record_path\` (via .decisionrecords-config)"
    elif [ -d "${this_directory}/doc/adr" ]
    then
      decision_record_path="doc/adr"
      info "Found Decision Record path for records \`$decision_record_path\` (via default old path)"
    elif [ -d "${this_directory}/doc/decision_records" ]
    then
      decision_record_path="doc/decision_records"
      info "Found Decision Record path for records \`$decision_record_path\` (via default new path)"
    fi
  fi
  invoke_response "decision_record_path()" "$decision_record_path"
}

##############################
# Config Items
##############################

function _get_decision_record_config_path() {
  decision_record_config_path "${1-}"
  echo "$decision_record_config_path"
}

function decision_record_config_path() {
  invoke "decision_record_config_path(${1-})"
  if [ -z "$decision_record_config_path" ]
  then
    local config_file
    if [ -n "${1-}" ]
    then
      config_file="$1/.decisionrecords-config"
    else
      config_file="$decision_record_root/.decisionrecords-config"
    fi

    info "Using config file: $config_file"

    decision_record_config_path="doc/decision_records" # Default value
    if [ -f "$config_file" ] && grep -E -e '^records=' "$config_file" >/dev/null 2>&1
    then
      decision_record_config_path="$(grep -E -e '^records=' "$config_file" | head -n 1 | cut -d= -f2)"
    else
      info "Configuration value 'records' not found in $config_file. Using the default value, \`$decision_record_config_path\`."
    fi
  fi

  invoke_response "decision_record_config_path(${1-})" "$decision_record_config_path"
}

function _get_decision_record_config_template_dir() {
  decision_record_config_template_dir
  echo "$decision_record_config_template_dir"
}

# shellcheck disable=SC2120
function decision_record_config_template_dir() {
  invoke "decision_record_config_template_dir()"

  if [ -z "$decision_record_root" ]
  then
    decision_record_root
  fi
  if [ -z "$decision_record_path" ]
  then
    decision_record_path
  fi

  if [ -z "$decision_record_config_template_dir" ]
  then
    local config_file
    config_file="$decision_record_root/.decisionrecords-config"

    decision_record_config_template_dir="$decision_record_path/.templates" # Default value
    if [ -f "$config_file" ] && grep -E -e '^templatedir=' "$config_file" >/dev/null 2>&1
    then
      decision_record_config_template_dir="$(grep -E -e '^templatedir=' "$config_file" | head -n 1 | cut -d= -f2)"
    else
      info "Configuration value 'templatedir' not found in $config_file. Using the default value, \`$decision_record_config_template_dir\`."
    fi
  fi

  if [ ! -e "$decision_record_root/$decision_record_config_template_dir" ]
  then
    error "Template Directory \`$decision_record_config_template_dir\` is missing. Unable to proceed."
    exit 1
  else
    invoke_response "decision_record_config_template_dir()" "$decision_record_config_template_dir"
  fi
}

function _get_decision_record_config_template_type() {
  decision_record_config_template_type
  echo "$decision_record_config_template_type"
}

function decision_record_config_template_type() {
  invoke "decision_record_config_template_type()"
  if [ -z "$decision_record_config_template_type" ]
  then
    if [ -z "$decision_record_root" ]
    then
      decision_record_root
    fi

    local config_file
    config_file="$decision_record_root/.decisionrecords-config"

    decision_record_config_template_type="md" # Default value
    if [ -f "$config_file" ] && grep -E -e '^filetype=' "$config_file" >/dev/null 2>&1
    then
      decision_record_config_template_type="$(grep -E -e '^filetype=' "$config_file" | head -n 1 | cut -d= -f2)"
    else
      info "Configuration value 'filetype' not found in $config_file. Using the default value, \`$decision_record_config_template_type\`."
    fi
  fi

  invoke_response "decision_record_config_template_type()" "$decision_record_config_template_type"
}

function _get_decision_record_config_template_file() {
  decision_record_config_template_file
  echo "$decision_record_config_template_file"
}

function decision_record_config_template_file() {
  invoke "decision_record_config_template_file()"
  if [ -z "$decision_record_config_template_file" ]
  then
    if [ -z "$decision_record_root" ]
    then
      decision_record_root
    fi

    local config_file
    config_file="$decision_record_root/.decisionrecords-config"

    decision_record_config_template_file="template" # Default value
    if [ -f "$config_file" ] && grep -E -e '^template=' "$config_file" >/dev/null 2>&1
    then
      decision_record_config_template_file="$(grep -E -e '^template=' "$config_file" | head -n 1 | cut -d= -f2)"
      if [ "$(grep -c -E -e '^template=' "$config_file")" -gt 1 ]
      then
        warning "Multiple Template configuration values detected. First value used. Please check your config file \`$config_file\` for values starting template="
      fi
    else
      info "Configuration value 'template' not found in $config_file. Using the default value, \`$decision_record_config_template_file\`."
    fi
  fi

  if [ -z "$decision_record_config_template_dir" ]
  then
    decision_record_config_template_dir
  fi
  if [ -z "$decision_record_config_template_type" ]
  then
    decision_record_config_template_type
  fi

  if [ -n "$decision_record_config_template_dir" ]
  then
    if [ ! -e "$decision_record_root/$decision_record_config_template_dir/$decision_record_config_template_file.$decision_record_config_template_type" ]
    then
      error "Template \`$decision_record_config_template_dir/$decision_record_config_template_file.$decision_record_config_template_type\` is missing. Unable to proceed."
      exit 1
    else
      invoke_response "decision_record_config_template_file()" "$decision_record_config_template_file"
    fi
  else
    error "Template directory not found."
    exit 1
  fi
}

function _get_decision_record_config_template_language() {
  decision_record_config_template_language
  echo "$decision_record_config_template_language"
}

function decision_record_config_template_language() {
  invoke "decision_record_config_template_language()"
  if [ -z "$decision_record_config_template_language" ]
  then
    if [ -z "$decision_record_language" ]
    then
      decision_record_language
    fi

    info "Using language $decision_record_language"

    if [ -z "$decision_record_root" ]
    then
      decision_record_root
    fi
    if [ -z "$decision_record_config_template_dir" ]
    then
      decision_record_config_template_dir
    fi
    if [ -z "$decision_record_config_template_file" ]
    then
      decision_record_config_template_file
    fi
    if [ -z "$decision_record_config_template_type" ]
    then
      decision_record_config_template_type
    fi

    if [ -n "$decision_record_config_template_dir" ] && [ -n "$decision_record_config_template_file" ] && [ -n "$decision_record_config_template_type" ]
    then
      debug "Got decision_record_config_template_dir of $decision_record_config_template_dir / Got decision_record_config_template_file of $decision_record_config_template_file"
      if [ -n "$decision_record_language" ]
      then
        debug "Got decision_record_language of $decision_record_language"
        debug "Trying paths: "
        debug "* $decision_record_root/$decision_record_config_template_dir/$decision_record_config_template_file.$decision_record_language.$decision_record_config_template_type"
        debug "* $decision_record_root/$decision_record_config_template_dir/$decision_record_config_template_file.$(echo "$decision_record_language" | cut -d- -f 1).$decision_record_config_template_type"
        debug "* $decision_record_root/$decision_record_config_template_dir/$decision_record_config_template_file.$(echo "$decision_record_language" | cut -d_ -f 1).$decision_record_config_template_type"
        if [ -e "$decision_record_root/$decision_record_config_template_dir/$decision_record_config_template_file.$decision_record_language.$decision_record_config_template_type" ]
        then
          debug "Found first one"
          decision_record_config_template_language="$decision_record_language"
        elif [ -e "$decision_record_root/$decision_record_config_template_dir/$decision_record_config_template_file.$(echo "$decision_record_language" | cut -d- -f 1).$decision_record_config_template_type" ]
        then
          debug "Found second one"
          decision_record_config_template_language="$(echo "$decision_record_language" | cut -d- -f 1)"
        elif [ -e "$decision_record_root/$decision_record_config_template_dir/$decision_record_config_template_file.$(echo "$decision_record_language" | cut -d_ -f 1).$decision_record_config_template_type" ]
        then
          debug "Found third one"
          decision_record_config_template_language="$(echo "$decision_record_language" | cut -d_ -f 1)"
        else
          debug "None found"
        fi
      fi
    fi
    invoke_response "decision_record_config_template_language()" "$decision_record_config_template_language"
  fi
}

##############################
# Create Items
##############################

function _get_decision_record_config_template_path() {
  decision_record_config_template_path
  echo "$decision_record_config_template_path"
}

function decision_record_config_template_path() {
  invoke "decision_record_config_template_path()"

  if [ -z "$decision_record_config_template_path" ]
  then
    if [ -z "$decision_record_config_template_dir" ]
    then
      decision_record_config_template_dir
    fi
    if [ -z "$decision_record_config_template_file" ]
    then
      decision_record_config_template_file
    fi
    if [ -z "$decision_record_config_template_language" ]
    then
      decision_record_config_template_language
    fi
    if [ -z "$decision_record_config_template_type" ]
    then
      decision_record_config_template_type
    fi

    if [ -z "$decision_record_config_template_language" ]
    then
      decision_record_config_template_path="$decision_record_config_template_dir/$decision_record_config_template_file.$decision_record_config_template_type"
    else
      decision_record_config_template_path="$decision_record_config_template_dir/$decision_record_config_template_file.$decision_record_config_template_language.$decision_record_config_template_type"
    fi
  fi

  if [ -z "$decision_record_root" ]
  then
    decision_record_root
  fi

  if [ -e "$decision_record_root/$decision_record_config_template_path" ]
  then
    invoke_response "decision_record_config_template_path()" "$decision_record_config_template_path"
  else
    error "Unable to find the template \`$decision_record_config_template_path\`."
    exit 1
  fi
}

function full_decision_record_path() {
  invoke "full_decision_record_path()"
  if [ -z "$full_decision_record_path" ]
  then
    if [ -z "$decision_record_path" ]
    then
      decision_record_path
    fi
    if [ -z "$decision_record_root" ]
    then
      decision_record_root
    fi
    full_decision_record_path="$decision_record_root/$decision_record_path"
    invoke_response "full_decision_record_path()" "$full_decision_record_path"
  fi
}

# shellcheck disable=SC2010 # ls | grep is required for speed in this case
function _get_next_ref() {
  invoke "_get_next_ref()"

  if [ -z "$full_decision_record_path" ]
  then
    full_decision_record_path
  fi

  last_reference="$(ls "$full_decision_record_path" | grep --extended-regexp --only-matching '^[0-9]{4}-' | sort --reverse --numeric-sort | sed -e 's/^0//' -e 's/-$//' | head -n 1)"
  next_reference=1
  if [ -n "$last_reference" ]
  then
    next_reference=$(( last_reference + 1 ))
  fi

  next_ref="${next_reference}:$(printf "%04d" "$next_reference")"
  invoke_response "_get_next_ref()" "$next_ref"
  echo "$next_ref"
}

function _make_slug() {
  invoke "_make_slug('$1')"
  # Slugify based on https://stackoverflow.com/a/63286099/5738
  slug="$(echo -n "$1" | iconv -c --to-code=ascii//TRANSLIT  | tr '[:upper:]' '[:lower:]' | sed -E -e 's/[^a-zA-Z0-9]+/-/g ; s/^-+|-+$//g')"
  invoke_response "_make_slug('$1')" "$slug"
  echo "$slug"
}

function _create() {
  invoke "_create(file='$1' backup='$2')"
  if [ -z "$full_decision_record_path" ]
  then
    full_decision_record_path
  fi
  target_file="$full_decision_record_path/$1"
  if [ -e "$target_file" ]
  then
    warning "File '$target_file' already exists."
  fi
  touch "$target_file"
  target_file="$file"
  invoke_response "_create(file='$1')" "$target_file"
}

function _write() {
  invoke "_write(file='$1' message='$2')"
  if [ -z "$full_decision_record_path" ]
  then
    full_decision_record_path
  fi
  target_file="$full_decision_record_path/$1"
  echo "$2" >> "$target_file"
  invoke_response "_write(file='$1' message='$2')" "<OUTPUT>"
}

function _set_status() {
  invoke "_set_status(file='$1' set_line='$2' append='$3')"
  local file
  local set_line
  local append=0
  if [ -z "$full_decision_record_path" ]
  then
    full_decision_record_path
  fi

  local in_status=0

  file="$1"
  _create "$1~"
  set_line="$2"
  if [ "$3" == "append" ]
  then
    append=1
  fi

  local _t_Status
  local _t_Accepted
  local _t_Proposed
  _t_Status="$( _t "Status" )"
  _t_Accepted="$( _t "Accepted" )"
  _t_Proposed="$( _t "Proposed" )"

  local status_set
  status_set=0

  local counter
  counter=0

  debug "File: $full_decision_record_path/$file"

  while IFS="" read -r line || [ -n "$line" ]
  do
    counter=$(( counter +1 ))
    if [[ "$line" =~ ^([\t ]*)\#\#([\t ]*)$_t_Status ]]
    then
      debug "0 Line matches ^\s*##\s*$_t_Status. Incrementing in_status to $(( in_status + 1 ))."
      in_status=1
      _write "$1~" "$line"
    elif [[ "$in_status" -gt 0 ]]
    then
      if [[ "$line" =~ ^([\t ]*)\#\# ]]
      then
        _write "$1~" "$line"
        in_status=0
      elif [[ "$append" -eq 0 ]]
      then
        if [[ "$line" =~ ^([\t ]*)($_t_Status: |)($_t_Accepted|$_t_Proposed|STATUS) ]]
        then
          _write "$1~" "$line"
          _write "$1~" "$set_line"
          status_set=1
        elif [[ "$line" =~ ^([\t ]*)$ ]]
        then
          in_status=$(( in_status + 1 ))
          if [ "$in_status" -eq 3 ] && [ "$status_set" -eq 0 ]
          then
            _write "$1~" "$set_line"
          else
            _write "$1~" "$line"
          fi
        else
          _write "$1~" "$line"
        fi
      elif [[ "$append" -eq 1 ]]
      then
        if [[ "$line" =~ ^([\t ]*)$ ]]
        then
          in_status=$(( in_status + 1 ))
          if [ "$in_status" -eq 3 ]
          then
            _write "$1~" "$set_line"
          fi
        fi
        _write "$1~" "$line"
      fi
    else
      _write "$1~" "$line"
    fi
  done < "$full_decision_record_path/$file"
  invoke_response "_set_status(file='$1' set_line='$2' append='$3')" "$(diff "$full_decision_record_path/$file~" "$full_decision_record_path/$file")"
  mv "$full_decision_record_path/$file~" "$full_decision_record_path/$file"
}

function _get_title() {
  invoke "_get_title(file='$1')"
  if [ -z "$decision_record_config_template_type" ]
  then
    decision_record_config_template_type
  fi
  if [ -z "$full_decision_record_path" ]
  then
    full_decision_record_path
  fi

  local title
  local lastline

  if [ -z "$1" ]
  then
    error "No file provided"
    exit 1
  elif [ ! -e "$1" ] && [ -e "$full_decision_record_path/$1" ]
  then
    file="$full_decision_record_path/$1"
  elif [ ! -e "$1" ]
  then
    error "File not found '$1'"
  else
    file="$1"
  fi

  while IFS="" read -r line || [ -n "$line" ]
  do
    if [ -n "$title" ]
    then
      break
    elif [ "$decision_record_config_template_type" == "md" ]
    then
      if [[ "$line" =~ ^([\t ]*)\# ]]
      then
        title="$(echo "$line" | cut -d\# -f2 | sed -e 's/^\s*// ; s/\s*$//' )"
      elif [[ "$line" =~ ^([\t ]*)title= ]]
      then
        title="$(echo "$line" | cut -d= -f2 | sed -e 's/^\s*// ; s/\s*$//' )"
      fi
    elif [ "$decision_record_config_template_type" == "rst" ]
    then
      if [[ "$line" =~ ^([\t ]*)([\#\*=~][\#\*=~][\#\*=~]) ]]
      then
        title="$lastline"
      elif [[ "$line" =~ ^([\t ]*)title= ]]
      then
        title="$(echo "$line" | cut -d= -f2 | sed -e 's/^\s*// ; s/\s*$//' )"
      fi
      lastline="$line"
    else
      error "File format $decision_record_config_template_type is not understood yet. Please submit a PR."
      exit 1
    fi
  done < "$file"

  if [ -z "$title" ]
  then
    error "Unable to find a title in $1. Please check and submit a PR."
    exit 1
  fi

  invoke_response "_get_title(file='$1')" "$title"
  echo "$title"
}

function _find_record() {
  invoke "_find_record($1)"
  if [ -z "$full_decision_record_path" ]
  then
    full_decision_record_path
  fi

  local file
  file="$1"

  if [[ "$1" =~ ([0-9]|[0-9][0-9]|[0-9][0-9][0-9]|[0-9][0-9][0-9][0-9]) ]]
  then
    local globname
    globname="$(printf "%04d" "$1")"
    file="$(basename "$(find "$full_decision_record_path" -type f -name "${globname}-*" | head -n 1)")"
  fi

  invoke_response "_find_record($1)" "$file"
  echo "$file"
}

# shellcheck disable=SC2001 # We need to use sed for this string replacement because it's complex
function _add_link() {
  invoke "_add_link(from='$1' to='$2' from_string='$3' to_string='$4' replace_status='$5')"
  
  if [ -z "$full_decision_record_path" ]
  then
    full_decision_record_path
  fi

  local from_file
  local from_title
  local from_string

  local to_file
  local to_title
  local to_string

  local replace_status

  from_file="$1"
  from_title="$(_get_title "$from_file")"
  from_string="$3"
  
  to_file="$2"
  to_title="$(_get_title "$to_file")"
  to_string="$4"
  
  replace_status='append'

  if [ "$decision_record_config_template_type" == "md" ]
  then
    from_line="$(echo "$from_string" | sed -e "s/\#/\[$to_title\]\($to_file\)/")"
    to_line="$(echo "$to_string" | sed -e "s/\#/\[$from_title\]\($from_file\)/")"
  elif [ "$decision_record_config_template_type" == "rst" ]
  then
    from_line="$(echo "$from_string" | sed -e "s/\#/\`$to_title\<$to_file\>\`_/")"
    to_line="$(echo "$to_string" | sed -e "s/\#/\`$from_title\<$from_file\>\`_/")"
  else
    error "File format $decision_record_config_template_type is not understood yet. Please submit a PR."
    exit 1
  fi

  if [ "$5" == "Replace_Status" ]
  then
    replace_status='replace'
  fi

  _set_status "$from_file" "$from_line" "append"
  _set_status "$to_file" "$to_line" "$replace_status"
}

function create_record() {
  invoke "create_record()"
  local next_reference
  local next_record
  local next_number
  if [ -z "$decision_record_config_template_path" ]
  then
    decision_record_config_template_path
  fi
  if [ -z "$decision_record_config_template_type" ]
  then
    decision_record_config_template_type
  fi
  
  if [ -z "$full_decision_record_path" ]
  then
    full_decision_record_path
  fi

  next_reference="$(_get_next_ref)"
  [[ $next_reference =~ ^([0-9]+):([0-9]+)$ ]]
  next_number="${BASH_REMATCH[1]}"
  next_record="${BASH_REMATCH[2]}"

  empty_command=1
  title=""
  status=""
  links=()
  supersedes=()
  amends=()
  deprecates=()

  while :; do
    case "${1-}" in
    --)
      break
      ;;
    -A | --accepted)
      empty_command=0
      if [ -n "${status}" ]
      then
        error "Status already set"
        exit 1
      fi
      status="$(_t "Accepted")"
      shift
      ;;
    -P | --proposed)
      empty_command=0
      if [ -n "${status}" ]
      then
        error "Status already set"
        exit 1
      fi
      status="$(_t "Proposed")"
      shift
      ;;
    -D | --draft)
      empty_command=0
      if [ -n "${status}" ]
      then
        error "Status already set"
        exit 1
      fi
      status="$(_t "Draft")"
      shift
      ;;
    -S | --status)
      empty_command=0
      if [ -n "${status}" ]
      then
        error "Status already set"
        exit 1
      fi
      status="${2-}"
      shift 2
      ;;
    -s | --super | --supersedes | -r | --replace | --replaces)
      empty_command=0
      exists=0
      link_file="$(_find_record "${2-}")"
      if [ ! -e "$full_decision_record_path/$link_file" ]
      then
        error "Link file is not found '$link_file'."
        exit 1
      fi
      for i in "${!supersedes[@]}"
      do
        if [ "${supersedes[$i]}" == "$link_file" ]
        then
          exists=1
        fi
      done
      [ "$exists" -eq 0 ] && supersedes+=("$link_file")
      shift 2
      ;;
    -l | --link | --links)
      empty_command=0
      exists=0
      link_file="$(_find_record "${2-}")"
      if [ ! -e "$full_decision_record_path/$link_file" ]
      then
        error "Link file is not found '$link_file'."
        exit 1
      fi
      for i in "${!links[@]}"
      do
        if [ "${links[$i]}" == "$link_file" ]
        then
          exists=1
        fi
      done
      link="$link_file"
      if [ "${3:0:1}" != '-' ] && [ "${4:0:1}" != '-' ]
      then
        link+=";${3-} #;${4-} #"
        shift 2
      else
        link+=";Linked with #;Linked with #"
      fi
      [ "$exists" -eq 0 ] && links+=("${link}")
      shift 2
      ;;
    -a | --amend | --amends)
      empty_command=0
      exists=0
      link_file="$(_find_record "${2-}")"
      if [ ! -e "$full_decision_record_path/$link_file" ]
      then
        error "Link file is not found '$link_file'."
        exit 1
      fi
      for i in "${!amends[@]}"
      do
        if [ "${amends[$i]}" == "$link_file" ]
        then
          exists=1
        fi
      done
      [ "$exists" -eq 0 ] && amends+=("$link_file")
      shift 2
      ;;
    -d | --deprecate | --deprecates)
      empty_command=0
      exists=0
      link_file="$(_find_record "${2-}")"
      if [ ! -e "$full_decision_record_path/$link_file" ]
      then
        error "Link file is not found '$link_file'."
        exit 1
      fi
      for i in "${!deprecates[@]}"
      do
        if [ "${deprecates[$i]}" == "$link_file" ]
        then
          exists=1
        fi
      done
      [ "$exists" -eq 0 ] && deprecates+=("$link_file")
      shift 2
      ;;
    -t | --title)
      empty_command=0
      if [ -n "${title}" ]
      then
        error "Title already set"
        exit 1
      fi
      title="${2-}"
      shift 2
      ;;
    -?*)
      error "Unknown option: $1"
      exit 1
      shift
      ;;
    *)
      break
      ;;
    esac
  done

  rest_of_args="$*"
  if [ -n "${title}" ] && [ -n "${rest_of_args}" ]
  then
    error "Title already set"
    exit 1
  elif [ -n "${rest_of_args}" ]
  then
    empty_command=0
    title="${rest_of_args}"
  fi

  if [ "$empty_command" -eq 1 ] || [ -z "${title}" ]
  then
    error "To create a record, you must at least specify a title. Unable to proceed."
    exit 1
  fi

  if [ -z "$status" ]
  then
    status="$(_t "Accepted")"
  fi

  record_file="$next_record-$(_make_slug "$title").$decision_record_config_template_type"
  sed -e "s/NUMBER/${next_number}/ ; s/TITLE/${title}/ ; s/DATE/${DR_DATE:-$(date +%Y-%m-%d)}/ ; s/STATUS/${status}/" "$decision_record_config_template_path" > "$full_decision_record_path/$record_file"

  for record in "${!supersedes[@]}"
  do
    _add_link "$record_file" "${supersedes[$record]}" "$(_t "Supersedes #")" "$(_t "Superseded by #")" "Replace_Status"
  done

  for record in "${!amends[@]}"
  do
    _add_link "$record_file" "${amends[$record]}" "$(_t "Amends #")" "$(_t "Amended by #")"
  done

  for record in "${!links[@]}"
  do
    _add_link "$record_file" "$(echo "${links[$record]}" | cut -d\; -f1)" "$(_t "$(echo "${links[$record]}" | cut -d\; -f2)")" "$(_t "$(echo "${links[$record]}" | cut -d\; -f3)")"
  done

  for record in "${!deprecates[@]}"
  do
    _add_link "$record_file" "${deprecates[$record]}" "$(_t "Deprecates #")" "$(_t "Deprecated by #")" "Replace_Status"
  done

  if [ -n "$DEBUG_FILENAME" ]
  then
    echo "$record_file"
  fi

  if [ -n "$DEBUG_FILECONTENT" ]
  then
    cat "$full_decision_record_path/$record_file"
  fi
}

function main() {
  decision_record_root
}

DEPTH=""
decision_record_root=""
decision_record_path=""
decision_record_config_path=""
decision_record_config_template_language=""
decision_record_config_template_path=""
decision_record_config_template_dir=""
decision_record_config_template_type=""
decision_record_config_template_file=""


if [[ "${BASH_SOURCE[0]}" == "${0}" ]]
then
  main
fi
