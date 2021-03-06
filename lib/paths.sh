#!/bin/bash

# Global paths
# Author: arctelix

drealpath(){
    "$(dotsys_dir)/bin/drealpath" "$@"
}


dotfiles_dir () {
  echo "$(platform_user_home)/.dotfiles"
}

dotsys_dir () {
  echo "$DOTSYS_REPOSITORY"

}

# depreciated
builtin_topic_dir () {
    echo "$(dotsys_dir)/builtins/$1"
}

dotsys_user_bin () {
    echo "$(dotsys_dir)/user/bin"
}

# Gets full path to topic based on topic config repo or active repo
# restrict:
# 'active'  Restrict to active user repo (do not check builtins)
# 'builtin' Restrict to builtin repo
# 'primary' Restrict to primary repo
# 'user'    Restrict to any user repo topic config repo or active repo or primary repo
topic_dir () {
    local topic="${1:-$topic}"
    local restrict="$2"
    local return_non_exist="$3"
    local path

    #debug "   - topic_dir $restrict:"

    # Installed repo (not dotsys)
    local repo="$(get_state_value "dotsys" "$topic" "!dotsys/dotsys")"

    if ! [ "$repo" ]; then
        # Check for topic alternate repo
        repo=$(get_topic_config_val "$topic" "repo")
        # use active repo if topic repo not found
        repo="${repo:-$(get_active_repo)}"
    fi

    # Do not use dotsys repo (default to primary repo)
    if [ "$restrict" = "user" ]; then
        if is_dotsys_repo; then
           repo="$(state_primary_repo)"
        fi

    # Restrict to primary
    elif [ "$restrict" = "primary" ]; then
        repo="$(state_primary_repo)"

    # Non restricted (installed, topic cfg, active, builtin)
    elif [ "$restrict" != "active" ]; then
        path="$(repo_dir "$repo")/$topic"
        if [ ! -d "$path" ]; then
            path="$(dotsys_dir)/builtins/$topic"
        fi
    fi

    # catch dotsys repo or well get .dotsys dir not builtins
    if is_dotsys_repo || [ "$restrict" = "builtin" ]; then
        path="$(dotsys_dir)/builtins/$topic"

    elif ! [ "$path" ]; then
        path="$(repo_dir "$repo")/$topic"
    fi

    # Return and Test for path
    echo "$path"
    [ -d "$path" ]
}

# converts supplied repo or active repo to full path
repo_dir () {
    local repo="${1}"
    local branch

    if ! [ "$repo" ]; then
        repo="$(get_active_repo)"
    fi

    if ! [ "$repo" ]; then
        return 1
    fi

    # catch dotsys repo
    if is_dotsys_repo; then
        # Git is in root not builtins
        repo="$DOTSYS_REPOSITORY"
    fi

    _split_repo_branch

    # catch abs path
    if [[ "$repo" = /* ]]; then
        echo "$repo"
    # relative to full path
    else
        echo "$(dotfiles_dir)/$repo"
    fi
}

user_stub_dir() {
    echo "$(dotsys_dir)/user/stubs"
}


get_user_or_builtin_file () {
    get_user_or_builtin f "$@"
}

# Searches user directory then builtin directory and returns unique names only
# user directory supersedes builtins
get_user_or_builtin () {
    local type="$1"
    local topic="$2"
    local find_name="$3"
    local rv

    debug "   - get_user_or_builtin_file for $topic $find_name"

    local u_dir="$(topic_dir "$topic" "user")"
    local u_files=()
    local b_dir="$(topic_dir "$topic" "builtin")"
    local b_files=()

    if [ "$type" = "a" ]; then
        type=""
    elif [ "$type" ];then
        type="-type $type"
    fi

    # check user directory for file
    if [ -d "$u_dir" ]; then
        u_files=( $(find "$u_dir" -mindepth 1 $type -name "$find_name" -not -name '\.*') )
    fi

    # check builtin directory for file
    if [ -d "$b_dir" ];then
        b_files=( $(find "$b_dir" -mindepth 1 $type -name "$find_name" -not -name '\.*') )
    fi

    local file
    # Add any builtin file name not already in user files
    for file in "${b_files[@]}";do
        if ! array_contains u_files "*$(basename "$file")"; then
            u_files+=( "$file" )
        fi
    done

    if ! [ "$u_files" ]; then return 1; fi

    for file in ${u_files[@]};do
        chmod 755 "$file"
    done

    debug "$(printf '    found: %s\n' "${u_files[@]}")"

    # return line separated list
    printf '%s\n' "${u_files[@]}"
}