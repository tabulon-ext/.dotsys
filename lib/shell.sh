#!/bin/bash

# Shell functions
# Author: arctelix

import platforms platform_user_home
import platforms generic_platform
import config_user config_shell_prompt
import config_user config_shell_output
import config_user config_shell_debug

# use 'shell_debug' to activate shell load debug
if config_shell_debug;then
    DEBUG_SHELL=true
fi

debug_shell () {
    if [ "$DEBUG_SHELL" = true ]; then
        printf "%b%b%b\n" $c_debug "$1" $rc 1>&2
    fi
}

shell_loaded_out () {
    if [ "$SHELL_LOADING_OUTPUT" = true ] || [ "$DEBUG_SHELL" = true ]; then
        printf "%b%b%b\n" "\e[0;92m" "$1" $rc
    fi
}

# Sets global flag for shell reload when topic matches "shell" or $active_shell
flag_reload () {
    local topic="$1"
    local flagged="$2"
    local active_shell="$ACTIVE_SHELL"
    local state=1

    debug "-- flag_reload $ACTIVE_SHELL"

    # Test if topic is current_shell or "required"
    if ! [ "$active_shell" ] || [ "$topic" = "$active_shell" ] || [ "$topic" = "shell" ];then
        state=0
        flagged="$topic"
        debug "FLAG RELOAD SHELL ($state): $flagged"
    fi
    echo "$flagged"
    return $state
}

# Resources active shell files
shell_reload () {
    local shell="${1:-$ACTIVE_SHELL}"
    local script=$2

    # Remove flag for shell reload
    export RELOAD_SHELL=""

    # The following error occurs when installing and zsh is active shell
    # locking failed for /cygdrive/c/Users/arcte/.zsh_history: no such file or directory
    # once the shell is reloaded the error no longer occurs and seems harmless
    if [ "$ACTIVE_LOGIN_SHELL" ];then
        exec -l $shell $script
    elif [ "$shell" ]; then
        exec $shell $script
    else
        exec -l $SHELL $script
    fi
}

# Activate/deactivate shell debug mode
shell_debug () {
    local state=0
    if [ "$DEBUG_SHELL" = "true" ]; then
        state=1
    fi

    config_shell_debug $state

    shell_reload
}

# Sources all required files for shell initialization
# all login shell init files must call this function
shell_init() {

    debug_shell "init_shell $1 $2"

    local shell="$(get_active "$1")"
    local file="$2"
    local login="$3"

    # Abort if active or spcified shell already initialized
    if [ "$SHELL_INITIALISED" = "$shell" ];then
        echo "already initialized $shell" 1>&2
        return
    fi

    # Change shells requires new environment
    if [ "$ACTIVE_SHELL" ] && [ "$ACTIVE_SHELL" != "$shell" ];then
        unset ACTIVE_SHELL
        debug_shell "exec $shell"
        shell_reload $shell
        return
    fi

    # INITIALIZE SHELL

    local home="$(platform_user_home)"
    local profile="$(get_file "profile" "$shell")"
    local shellrc="$(get_file "rcfile" "$shell")"

    SHELL_INITIALISED="$shell"      # Prevent calling this function from init_shell
    SHELL_LOADING="$shell"          # Prevent execution of config files when set 'false'
    ACTIVE_SHELL="$shell"           # Currently active shell
    SHELL_FILES_LOADED=("$file")    # All sourced shell files

    # Check if user wants to see the output
    if config_shell_output; then
        SHELL_LOADING_OUTPUT="true"
    fi

    # Check for debug mode
    if config_shell_debug; then
        DEBUG_SHELL="true"
    fi

    # Prevent crlf line ending errors on windows bash
    if [ $shell = "bash" ] && [ "$(generic_platform)" = "windows" ]; then
        set -o igncr >/dev/null 2>&1
    fi

    shell_loaded_out "› DS INITIALIZING $shell from $file"

    # load global rc file
    [ "$file" != ".shellrc" ] && load_source_file "$home/.shellrc" "RCFILE"

    # load shells uniqu rc file
    [ "$file" != "$shellrc" ] && load_source_file "$home/$shellrc" "RCFILE"

    if [ "$login" ];then

        ACTIVE_LOGIN_SHELL="$SHELL_INITIALISED"

        # Load global .profile if it exists
        [ "$file" != ".profile" ] && load_source_file "$home/.profile" "PROFILE"

        # Load shells unique profile ie:.zsh_profile if it exists
        [ "$file" != "$profile" ] && load_source_file "$home/$profile" "PROFILE"

        shell_loaded_out "› LOADING PROFILE $file"
    else
        shell_loaded_out "› LOADING RCFILE $file"
    fi

    # Add the system logo to prompt
    shell_prompt

    # Prevent reloading of shell files
    SHELL_LOADING="false"
}

load_source_file(){
    local file="$1"
    local init_file="$2"
    local file_name="$(basename "$file")"
    local topic="$(basename "$(dirname "$file")")"

    if [ ! -f "$file" ]; then return;fi

    if [ "$init_file" ]; then
        shell_loaded_out "› LOADING $init_file $file_name"
    else
        shell_loaded_out "  - loading $topic/$file_name"
    fi
    source "$file"
    SHELL_FILES_LOADED+=("$file_name")
}


# Native shell init files (for reference)
# bash )  shellrc=".bashrc";   profile=".bash_profile";;
# zsh  )  shellrc=".zshrc";    profile=".zprofile";;
# ksh  )  shellrc=".kshrc";    profile=".profile";;
# csh  )  shellrc=".cshrc";    profile=".login";;
# tcsh )  shellrc=".tcshrc";   profile=".login";;

# Retrieves the correct shellrc or profile for each shell
# We implement separate profiles for each shell users should
# customize thees files when there are shell specific requirements
get_file () {
    local file="$1"
    local shell="${2:-"$ACTIVE_SHELL"}"
    local rcfile
    local profile

    case "$shell" in
        bash )  rcfile=".bashrc";   profile=".bash_profile";;
        zsh  )  rcfile=".zshrc";    profile=".zsh_profile";;
        ksh  )  rcfile=".kshrc";    profile=".ksh_profile";;
        csh  )  rcfile=".cshrc";    profile=".csh_login";;
        tcsh )  rcfile=".tcshrc";   profile=".tcsh_login";;
    esac

    if [ "$file" = "profile" ]; then
        echo "$profile"
    else
        echo "$rcfile"
    fi
}


# Determine active shell from input
# Root shell can use "shell" determine automatically
get_active () {

    local input="$1"
    local result

    if ! [ "$input" ] && [ "$ACTIVE_SHELL" ]; then echo "$ACTIVE_SHELL"; return; fi

    # Try to parse $0 or parse from error message
    if [ "$input" = "shell" ]; then
        result="$(shell_from_string "$0" || shell_from_string "$(error_string 2>&1)")"

    # Parse shell name from input
    else
        result="$(shell_from_string "$input")"
    fi

    echo "${result:-unknown}"

}

# Parse input string for shell name
shell_from_string() {
    local result
    case "$1" in
        *bash* )    result=bash;;
        *zsh*  )    result=zsh;;
        *ksh*  )    result=ksh;;
        *csh*  )    result=csh;;
        *tcsh* )    result=tcsh;;
        shell  )    result=shell;;
    esac
    echo "$result"
    [ "$result" ]
}

is_shell_topic () {
    local topic="${1:-$topic}"
    [ "$(shell_from_string "$topic")" ]
}


# Sets the dotsys prompt for the active shell
# Omit mode arg to check for user preference
# or use 'on' or 'off' to force
shell_prompt () {

    local mode="$1"
    local dsprompt
    local new_line

    # Only use dotsys prompt if enabled by user
    if ! [ "$mode" ] && ! config_shell_prompt; then return; fi

    # move new line prefix to front of |DS|
    if [[ "$PS1" == *$'\n'* ]];then
        new_line=$'\n'
        PS1="${PS1/$'\n'}"
    fi

    if [ "$ACTIVE_SHELL" = "zsh" ];then
        autoload -Uz colors && colors
        dsprompt="${new_line}$fg[green]|DS|$rc"
    else
        # Color codes must be wrapped in \[...\]
        dsprompt="${new_line}\[$l_green\]|DS|\[$rc\]"
    fi

    # Toggle off
    if [ "$mode" = "off" ]; then
        PS1="${PS1/$dsprompt}"
    # Toggle on
    elif [ "$PS1" = "${PS1/$dsprompt}" ]; then
        PS1="$dsprompt$PS1"
    fi
}