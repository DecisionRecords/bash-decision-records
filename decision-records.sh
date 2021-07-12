#!/bin/bash

# Translate Function
function _t() {
  config_language="$(_get_config_language)"
  if [[ "$config_language" =~ de* ]]
  then
    case "$1" in
      'Accepted') echo "Akzeptiert" ; return ;;
      'Proposed') echo "Vorgeschlagen" ; return ;;
      'Superseded by') echo "Ersetzt durch #" ; return ;;
      'Supersedes') echo "Ersetzt #" ; return ;;
      'Amends') echo "Ändert #" ; return ;;
      'Amended by') echo "Geändert von #" ; return ;;
      'Deprecates') echo "Veraltet #" ; return ;;
      'Deprecated by') echo "Veraltet von #" ; return ;;
      'Linked with') echo "Verknüpft mit #" ; return ;;
    esac
  elif [[ "$config_language" =~ fr* ]]
  then
    case "$1" in
      'Accepted') echo "Accepté" ; return ;;
      'Proposed') echo "Proposé" ; return ;;
      'Superseded by') echo "Remplacé par #" ; return ;;
      'Supersedes') echo "Remplace #" ; return ;;
      'Amends') echo "Modifie #" ; return ;;
      'Amended by') echo "Modifié par #" ; return ;;
      'Deprecates') echo "Obsolète #" ; return ;;
      'Deprecated by') echo "Obsolète par #" ; return ;;
      'Linked with') echo "Liée à #" ; return ;;
    esac
  elif [[ "$config_language" =~ jp* ]]
  then
    case "$1" in
      'Accepted') echo "承認された" ; return ;;
      'Proposed') echo "提案された" ; return ;;
      'Superseded by') echo "#に置き換えられました" ; return ;;
      'Supersedes') echo "#を置き換える" ; return ;;
      'Amends') echo "#を修正" ; return ;;
      'Amended by') echo "#によって修正されました" ; return ;;
      'Deprecates') echo "#を非推奨" ; return ;;
      'Deprecated by') echo "#によって廃止予定" ; return ;;
      'Linked with') echo "#とリンク" ; return ;;
    esac
  fi
  echo "$1"
}

function _get_config_language() {
  invoke "_get_config_language()"
  local config_file
  local config_language
  config_file="$(find_root_path)/.decisionrecords-config"

  config_language=""
  if [ -f "$config_file" ] && grep --extended-regexp --regexp='^language=' "$config_file" >/dev/null 2>&1
  then
    config_language="$(grep --extended-regexp --regexp='^language=' "$config_file" | head -n 1 | cut -d= -f2)"
    if [ "$(grep --count --extended-regexp --regexp='^language=' "$config_file")" -gt 1 ]
    then
      warning "Multiple Template configuration values detected. First value used. Please check your config file \`$config_file\` for values starting language="
    fi
  else
    info "Configuration value 'language' not found in $config_file. Using the default value, \`$config_language\`."
  fi
  
  invoke_response "_get_config_language()" "$config_language"
  echo "$config_language"
}

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
    if [ -f "$config_file" ] && grep --extended-regexp --regexp='^records=' "$config_file" >/dev/null 2>&1
    then
      config_path="$(grep --extended-regexp --regexp='^records=' "$config_file" | head -n 1 | cut -d= -f2)"
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
    if [ -f "$config_file" ] && grep --extended-regexp --regexp='^templatedir=' "$config_file" >/dev/null 2>&1
    then
      config_path="$(grep --extended-regexp --regexp='^templatedir=' "$config_file" | head -n 1 | cut -d= -f2)"
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

function decision_record_config_template_type() {
  invoke "decision_record_config_template_type()"
  if [ -z "$decision_record_config_template_type" ]
  then
    local config_file
    local config_path
    config_file="$(find_root_path)/.decisionrecords-config"

    config_path="md" # Default value
    if [ -f "$config_file" ] && grep --extended-regexp --regexp='^filetype=' "$config_file" >/dev/null 2>&1
    then
      config_path="$(grep --extended-regexp --regexp='^filetype=' "$config_file" | head -n 1 | cut -d= -f2)"
    else
      info "Configuration value 'filetype' not found in $config_file. Using the default value, \`$config_path\`."
    fi
  fi

  invoke_response "decision_record_config_template_type()" "$config_path"
  echo "$config_path"
}

function decision_record_config_template_file() {
  invoke "decision_record_config_template_file()"
  if [ -z "$decision_record_config_template_file" ]
  then
    local config_file
    local config_path
    config_file="$(find_root_path)/.decisionrecords-config"

    config_path="template" # Default value
    if [ -f "$config_file" ] && grep --extended-regexp --regexp='^template=' "$config_file" >/dev/null 2>&1
    then
      config_path="$(grep --extended-regexp --regexp='^template=' "$config_file" | head -n 1 | cut -d= -f2)"
      if [ "$(grep --count --extended-regexp --regexp='^template=' "$config_file")" -gt 1 ]
      then
        warning "Multiple Template configuration values detected. First value used. Please check your config file \`$config_file\` for values starting template="
      fi
    else
      info "Configuration value 'template' not found in $config_file. Using the default value, \`$config_path\`."
    fi
  fi

  local find_root_path
  local decision_record_config_template_dir
  local template_type
  find_root_path="$(find_root_path)"
  decision_record_config_template_dir="$(decision_record_config_template_dir)"
  template_type="$(decision_record_config_template_type)"

  if [ -n "$decision_record_config_template_dir" ]
  then
    if [ ! -e "$find_root_path/$decision_record_config_template_dir/$config_path.$template_type" ]
    then
      error "Template \`$decision_record_config_template_dir/$config_path.$template_type\` is missing. Unable to proceed." 1
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
    local config_language
    config_language="$(_get_config_language)"
  fi

  info "Using language $config_language"

  local find_root_path
  local decision_record_config_template_dir
  local decision_record_config_template_file
  local template_type
  find_root_path="$(find_root_path)"
  decision_record_config_template_dir="$(decision_record_config_template_dir)"
  decision_record_config_template_file="$(decision_record_config_template_file)"
  template_type="$(decision_record_config_template_type)"
  if [ -n "$decision_record_config_template_dir" ] && [ -n "$decision_record_config_template_file" ]
  then
    if [ -n "$config_language" ] && [ -e "$find_root_path/$decision_record_config_template_dir/$decision_record_config_template_file.$config_language.$template_type" ]
    then
      invoke_response "decision_record_config_template_language()" "$config_language"
      echo "$config_language"
    elif [ -n "$config_language" ] && [ -e "$find_root_path/$decision_record_config_template_dir/$decision_record_config_template_file.$(echo "$config_language" | cut -d_ -f 1).$template_type" ]
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

function get_template_path() {
  invoke "get_template_path()"
  if [ -z "$decision_record_config_template_path" ]
  then
    local decision_record_config_template_dir
    local decision_record_config_template_file
    local decision_record_config_template_language
    local template_type
    decision_record_config_template_dir="$(decision_record_config_template_dir)"
    decision_record_config_template_file="$(decision_record_config_template_file)"
    decision_record_config_template_language="$(decision_record_config_template_language)"
    template_type="$(decision_record_config_template_type)"
    if [ -z "$decision_record_config_template_language" ]
    then
      decision_record_config_template_path="$decision_record_config_template_dir/$decision_record_config_template_file.$template_type"
    else
      decision_record_config_template_path="$decision_record_config_template_dir/$decision_record_config_template_file.$decision_record_config_template_language.$template_type"
    fi
  fi

  local find_root_path
  find_root_path="$(find_root_path)"
  if [ -e "$find_root_path/$decision_record_config_template_path" ]
  then
    invoke_response "decision_record_config_template_file()" "$decision_record_config_template_path"
    echo "$decision_record_config_template_path"
  else
    error "Unable to find the template \`$decision_record_config_template_path\`."
  fi
}

# shellcheck disable=SC2010 # ls | grep is required for speed in this case
function _get_next_ref() {
  invoke "_get_next_ref()"

  local find_record_path
  find_record_path="$(find_root_path)/$(find_record_path)"

  last_reference="$(ls "$find_record_path" | grep --extended-regexp --only-matching '^[0-9]{4}-' | sort --reverse --numeric-sort | sed --expression='s/^0//' -e 's/-$//' | head -n 1)"
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
  slug="$(echo -n "$1" | iconv -c --to-code=ascii//TRANSLIT  | tr '[:upper:]' '[:lower:]' | sed --regexp-extended --expression='s/[^a-zA-Z0-9]+/-/g ; s/^-+|-+$//g')"
  invoke_response "_make_slug('$1')" "$slug"
  echo "$slug"
}

function _create() {
  invoke "_create(file='$1')"
  if [ -n "$1" ]
  then
    target_file="$1"
  else
    target_file="$(mktemp)"
  fi
  if [ -e "$target_file" ]
  then
    warning "File '$target_file' already exists."
  fi
  touch "$target_file"
  invoke_response "_create(file='$1')" "$target_file"
}

function _write() {
  if [ -n "$target_file" ]
  then
    error "No file set. Please run _create() first."
  fi
  echo "$1" >> "$target_file"
}

function _set_status() {
  invoke "_set_status(file='$1' set_line='$2' append='$3')"
  local file
  local set_line
  local append=0

  local in_status=0
  
  file="$1"
  _create "$1~"
  set_line="$2"
  if [ "$3" == "append" ]
  then
    append=1
  fi

  while IFS="" read -r line || [ -n "$line" ]
  do
    if [[ "$line" =~ ^([\t ]*)\#\#([\t ]*)Status ]]
    then
      in_status=1
      _write "$line"
    elif [[ "$in_status" -gt 0 ]]
    then
      if [[ "$line" =~ ^([\t ]*)\#\# ]]
      then
        _write "$line"
        in_status=0
      elif [[ "$append" -eq 0 ]] && [[ "$line" =~ ^([\t ]*)(Status: |)(Accepted|Proposed|STATUS) ]]
      then
        _write "$set_line"
      elif [[ "$append" -eq 1 ]]
      then
        if [[ "$line" =~ ^([\t ]*)$ ]]
        then
          in_status=$(( in_status + 1 ))
        fi
        if [ "$in_status" -eq 3 ]
        then
          _write "$set_line"
        fi
        _write "$line"
      fi
    else
      _write "$line"
    fi
  done < "$file"
  mv "$file~" "$file"
  invoke_response "_set_status(file='$1' set_line='$2' append='$3')" "Done"
}

function _get_title() {
  invoke "_get_title(file='$1')"
  local title
  local decision_record_config_template_type
  decision_record_config_template_type="$(decision_record_config_template_type)"
  local lastline

  while IFS="" read -r line || [ -n "$line" ]
  do
    if [ -n "$title" ]
    then
      break
    elif [ "$decision_record_config_template_type" == "md" ]
    then
      if [[ "$line" =~ ^([\t ]*)\# ]]
      then
        title="$(echo "$line" | cut -d\# -f2)"
      elif [[ "$line" =~ ^([\t ]*)title= ]]
      then
        title="$(echo "$line" | cut -d= -f2)"
      fi
    elif [ "$decision_record_config_template_type" == "rst" ]
    then
      if [[ "$line" =~ ^([\t ]*)([\#\*=~][\#\*=~][\#\*=~]) ]]
      then
        title="$lastline"
      elif [[ "$line" =~ ^([\t ]*)title= ]]
      then
        title="$(echo "$line" | cut -d= -f2)"
      fi
      lastline="$line"
    else
      error "File format $decision_record_config_template_type is not understood yet. Please submit a PR." 1
    fi
  done < "$file"

  if [ -z "$title" ]
  then
    error "Unable to find a title in $1. Please check and submit a PR." 1
  fi
  
  invoke_response "_get_title(file='$1')" "$title"
  echo "$title"
}

# shellcheck disable=SC2001 # We need to use sed for this string replacement because it's complex
function _add_link() {
  invoke "_add_link(from='$1' to='$2' from_string='$3' to_string='$4' replace_status='$5')"
  local from_file="$1"
  local to_file="$2"
  local from_title
  from_title="$(_get_title "$from_file")"
  local to_title
  to_title="$(_get_title "$to_file")"
  local from_string="$3"
  local to_string="$4"
  local replace_status='append'

  local decision_record_config_template_type
  decision_record_config_template_type="$(decision_record_config_template_type)"
  
  if [ "$decision_record_config_template_type" == "md" ]
  then
    from_line="$(echo "$from_string" | sed -e "s/#/\[$to_title\]\($to_file\)/")"
    to_line="$(echo "$to_string" | sed -e "s/#/\[$from_title\]\($from_file\)/")"
  elif [ "$decision_record_config_template_type" == "rst" ]
  then
    from_line="$(echo "$from_string" | sed -e "s/#/\`$to_title\<$to_file\>\`_/")"
    to_line="$(echo "$to_string" | sed -e "s/#/\`$from_title\<$from_file\>\`_/")"
  else
    error "File format $decision_record_config_template_type is not understood yet. Please submit a PR." 1
  fi

  if [ "$5" == "Replace_Status" ]
  then
    replace_status='replace'
  fi

  _set_status "$from_file" "$from_line" "leave"
  _set_status "$to_file" "$to_line" "$replace_status"
}

function create_record() {
  invoke "create_record()"
  local find_record_path
  local next_reference
  local next_record
  local next_number
  local template_path
  local template_type
  find_record_path="$(find_root_path)/$(find_record_path)"
  next_reference="$(_get_next_ref)"
  [[ $next_reference =~ ^([0-9]+):([0-9]+)$ ]]
  next_number="${BASH_REMATCH[1]}"
  next_record="${BASH_REMATCH[2]}"
  template_path="$(get_template_path)"
  template_type="$(decision_record_config_template_type)"

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
        error "Status already set" 1
      fi
      status="$(_t "Accepted")"
      shift
      ;;
    -P | --proposed)
      empty_command=0
      if [ -n "${status}" ]
      then
        error "Status already set" 1
      fi
      status="$(_t "Proposed")"
      shift
      ;;
    -S | --status)
      empty_command=0
      if [ -n "${status}" ]
      then
        error "Status already set" 1
      fi
      status="${2-}"
      shift 2
      ;;
    -s | --super | --supersedes | -r | --replace | --replaces)
      empty_command=0
      exists=0
      for i in "${!supersedes[@]}"
      do
        if [ "${supersedes[$i]}" == "${2-}" ]
        then
          exists=1
        fi
      done
      [ "$exists" -eq 0 ] && supersedes+=("${2-}")
      shift 2
      ;;
    -l | --link | --links)
      empty_command=0
      exists=0
      for i in "${!links[@]}"
      do
        if [ "${links[$i]}" == "${2-}" ]
        then
          exists=1
        fi
      done
      link="${2-}"
      if [ "${3:0:1}" != '-' ] && [ "${4:0:1}" != '-' ]
      then
        link+=";${3-};${4-}"
        shift 2
      else
        link+=";Linked with;Linked with"
      fi
      [ "$exists" -eq 0 ] && links+=("${link}")
      shift 2
      ;;
    -a | --amend | --amends)
      empty_command=0
      exists=0
      for i in "${!amends[@]}"
      do
        if [ "${amends[$i]}" == "${2-}" ]
        then
          exists=1
        fi
      done
      [ "$exists" -eq 0 ] && amends+=("${2-}")
      shift 2
      ;;
    -d | --deprecate | --deprecates)
      empty_command=0
      exists=0
      for i in "${!deprecates[@]}"
      do
        if [ "${deprecates[$i]}" == "${2-}" ]
        then
          exists=1
        fi
      done
      [ "$exists" -eq 0 ] && deprecates+=("${2-}")
      shift 2
      ;;
    -t | --title)
      empty_command=0
      if [ -n "${title}" ]
      then
        error "Title already set" 1
      fi
      title="${2-}"
      shift 2
      ;;
    -?*)
      error "Unknown option: $1" 1
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
    error "Title already set" 1
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

  record_file="$next_record-$(_make_slug "$title").$template_type"
  sed -e "s/NUMBER/${next_number}/ ; s/TITLE/${title}/ ; s/DATE/${DR_DATE:-$(date +%Y-%m-%d)}/ ; s/STATUS/${status}/" "$template_path" > "$find_record_path/$record_file"

  for record in "${!supersedes[@]}"
  do
    _add_link "$record_file" "${supersedes[$record]}" "$(_t "Supersedes")" "$(_t "Superseded by")" "Replace_Status"
  done

  for record in "${!amends[@]}"
  do
    _add_link "$record_file" "${amends[$record]}" "$(_t "Amends")" "$(_t "Amended by")"
  done

  for record in "${!links[@]}"
  do
    _add_link "$record_file" "$(echo "${links[$record]}" | cut -d\; -f1)" "$(_t "$(echo "${links[$record]}" | cut -d\; -f2)")" "$(_t "$(echo "${links[$record]}" | cut -d\; -f3)")"
  done

  for record in "${!deprecates[@]}"
  do
    _add_link "$record_file" "${deprecates[$record]}" "$(_t "Deprecates")" "$(_t "Deprecated by")" "Replace_Status"
  done

  echo "$record_file"
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
