#!/usr/bin/env bash

state_dir () {
  echo "$(dotsys_dir)/state"
}

state_file () {
    echo "$(state_dir)/${1}.state"
}
# adds key:value if key:value does not exist (value optional)
state_install() {
  local file="$(state_file "$1")"
  local key="$2"
  local val="$3"

  if ! [ -f "$file" ]; then return 1;fi

  grep -q "$(grep_kv)" "$file" || echo "${key}:${val}" >> "$file"
}

# removes key:value if key and value exist (value optional)
state_uninstall () {
  local file="$(state_file "$1")"
  local temp="$(state_dir)/temp_$1.state"
  local key="$2"
  local val="$3"



  if ! [ -f "$file" ]; then return 1;fi
  debug "   - state_uninstall: f:$file grep ${key}:${val}"

  # grep -v fails on last item so we have to test then remove
  grep -q "$(grep_kv)" "$file"
  if [ $? -eq 0 ]; then
     debug "   - state_uninstall FOUND ${key}:${value}, uninstalling"
     grep -v "$(grep_kv)" "$file" > "$temp"
     mv -f "$temp" "$file"
  else
     debug "   - state_uninstall NOT FOUND: f:$file grep ${key}:${val}"
  fi


}

grep_kv (){
    local k
    local v
    if [ "$val" ];then  v="${val}\$"; else v="$val"; fi
    if [ "$key" ];then  k="^${key}"; else k="$key" ;fi
    echo "${k}:${v}"
}


# test if key and or value exists in state
# if no value is supplied also checks if installed on system
is_installed () {
    local state="$1"
    local key="$2"
    shift;shift
    local val

    usage="is_installed <state> <key> [<val>] [<option>]"
    usage_full="
        -s | --silent        Silence warnings
    "
    local silent
    while [[ $# > 0 ]]; do
        case "$1" in
        -s | --silent )      silent="$1" ;;
        *)  uncaught_case "$1" "state" "key" "val" ;;
        esac
        shift
    done

    local installed=1
    local manager="$(get_topic_manager "$key")"
    local system_ok

    debug "-- is_installed got: $state ($key:$var)"

    # if state is "system" then a system install is acceptable
    # so bypass warnings and just return 0
    if [ "$state" = "system" ]; then
        state="dotsys"
        system_ok="true"
    elif [ "$manager" ]; then
        state="$manager"
        val="" # managers do not track repo
        debug "   is_installed: MANAGER skip dotsys state & checking ${state}.state!"
    fi

    # test if in specified state file
    in_state "$state" "$key" "$val"
    installed=$?

    debug "   is_installed in: $state = $installed"

    # Check if installed by manager ( packages installed via package.yaml file )
#    if [ "$state" = "dotsys" ] && ! [ "$installed" -eq 0 ]; then
#        local manager="$(get_topic_manager "$key")"
#        in_state "$manager" "$key" "$val"
#        installed=$?
#        debug "   - is_installed by manager: ${manager:-not managed} -> $installed"
#    fi

    # Check if installed on system, not managed by dotsys
    if ! [ "$installed" -eq 0 ] && ! [ "$val" ]; then
        local installed_test="$(get_topic_config_val "$key" "installed_test")"
        if cmd_exists "${installed_test:-$key}"; then
            if [ "$system_ok" ]; then
                installed=0
            elif ! [ "$silent" ]; then
                if [ "$action" = "uninstall" ]; then
                    warn "$(printf "Although %b$key is installed%b, it was not installed by dotsys.
                    $spacer You will have to %buninstall it by whatever means it was installed.%b" $green $rc $yellow $rc) "
                    installed=1
                elif ! [ "$force" ]; then
                    warn "$(printf "Although %b$key%b is installed, it is %bnot managed by dotsys%b.
                    $spacer Use %bdotsys install $key --force%b to allow dotsys to manage it." $green $rc $red $rc $yellow $rc)"
                    installed=0
                fi
            fi
        fi
        debug "   is_installed by other means -> $installed"
    fi

    debug "   is_installed ($key:$val) final -> $installed"

    return $installed
}

# Test if key and or value exists in state file
# use "!$key" to negate keys containing "$key"
# use "!$val" to negate values containing "$val"
# ie: key="!repo" will not match keys "user_repo:" or "repo:" etc..
in_state () {
  local state="$1"
  local file="$(state_file "$state")"
  if ! [ -f "$file" ]; then return 1;fi
  local key="$2"
  local val="$3"
  local results
  local not_key="$key"
  local not_val="$val"
  local not
  local r

  debug "   - in_state check '$state' for '$key:$val'"

  if [[ "$key" == "!"* ]]; then
    not_key="${key#!}.*"
    key=""
    not="true"
  fi
  if [[ "$val" == "!"* ]]; then
    not_val=".*${val#!}"
    val=""
    not="true"
  fi

  results="$(grep "$(grep_kv)" "$file")"
  local status=$?
  debug "     in_state grep '$(grep_kv)' = $status"
  debug "     in_state grep result:$(echo "$results" | indent_lines)"

  if [ "$not" ]; then
      for r in $results; do
        if [ "$r" ] && ! [[ "$r" =~ ${not_key}:${not_val} ]]; then
            debug "$indent -> testing $r !=~ '${not_key}:${not_val}' = 0"
            return 0
        fi
        debug "$indent -> testing $r !=~ '${not_key}:${not_val}' = 1"
      done
      return 1
  fi

  debug "$indent -> in_state = $status"
  return $status
}

# gets value for unique key
get_state_value () {
  local key="$1"
  local file="$(state_file "${2:-dotsys}")"
  local status=0

  local line="$(grep "^$key:.*$" "$file")"
  status=$?
  local val="${line#*:}"
  if [ "$val" = "1" ] || [ "$val" = "0" ]; then
    status=$val
  elif [ "$val" ]; then
    echo "$val"
  fi
  return $status
}

# sets value for unique key
set_state_value () {
  local key="$1"
  local val="$2"
  local state="${3:-dotsys}"
  state_uninstall "$state" "$key"
  state_install "$state" "$key" "$val"
}

# sets / gets primary repo value
state_primary_repo(){
  local repo="$1"
  local key="user_repo"

  if [ "$repo" ]; then
    set_state_value "$key" "$repo" "user"
  else
    echo "$(get_state_value "$key" "user")"
  fi
}

# get list of existing state names
get_state_list () {
    local file_paths="$(find "$(state_dir)" -mindepth 1 -maxdepth 1 -type f -not -name '\.*')"
    local state_names=
    local p
    for p in ${file_paths[@]}; do
        local file_name="$(basename "$p")"
        echo "${file_name%.state} "
    done
}

freeze_states() {

    freeze_state "user"
    freeze_state "dotsys"
    freeze_state "repos"

    local s
    for s in $(get_state_list); do
        if is_manager "$s"; then
            freeze_state "$s"
        fi
    done
}

freeze_state() {
    local state="$1"
    local file="$(state_file "$state")"
    if ! [ -s "$file" ]; then return;fi

    task "Freezing" "$(printf "%b$state state%b:" $green $cyan)"
    while IFS='' read -r line || [[ -n "$line" ]]; do
        #echo " - $line"
        freeze_msg "${line%:*}" "${line#*:}"

    done < "$file"
}

get_topic_list () {
    local dir="$1"
    local force="$2"
    local list
    local topic

    if [ "$dir" = "$DOTSYS_REPOSITORY" ]; then
        # ALWAYS GET INSTALLED TOPICS FOR DOTSYS
        force=
        # USE BUILTIN TOPICS FOR DOTSYS
        dir="$DOTSYS_REPOSITORY/builtins"
    fi

    # only installed topics when not installing unless forced
    if [ "$action" != "install" ] && ! [ "$force" ]; then
        while read line; do
            topic=${line%:*}
            # skip system keys
            if [[ "$STATE_SYSTEM_KEYS" =~ $topic ]]; then continue; fi
            echo "$topic"
        done < "$(state_file "dotsys")"
    # all defined topic directories
    else
        if ! [ -d "$dir" ];then return 1;fi
        get_dir_list "$dir"
    fi
}

get_installed_topic_paths () {
    local list
    local topic
    local repo

    while read line; do
        topic=${line%:*}
        repo=${line#*:}
        # skip system keys
        if [[ "$STATE_SYSTEM_KEYS" =~ $topic ]]; then continue; fi

        if [ "$repo" = "dotsys/dotsys" ]; then
            repo="$DOTSYS_REPOSITORY/builtins"

        else
            repo="$(dotfiles_dir)/$repo"
        fi

        echo "$repo/$topic"

    done < "$(state_file "dotsys")"
}