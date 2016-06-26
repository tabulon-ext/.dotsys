#!/bin/sh

# Returns a list directory names in a directory
get_dir_list () {
    local dir="$1"
    local force="$2"
    local list
    local t

    if ! [ -d "$dir" ];then return 1;fi
    list="$(find "$dir" -mindepth 1 -maxdepth 1 -type d -not -name '\.*')"

    for t in ${list[@]}; do
        echo "$(basename "$t") "
    done
}

# return a list of unique values
unique_list () {
    local var="$1"
    local seen
    local word

    for word in $var; do
      case $seen in
        $word\ * | *\ $word | *\ $word\ * | $word)
          # already seen
          ;;
        *)
          seen="$seen $word"
          ;;
      esac
    done
    echo $seen
}

remove_string_from_file () {
    local file="$1"
    local string="$2"
    ex "+g|$string|d" -cwq "$file"
}

rename_all() {
    . "$DOTSYS_LIBRARY/terminalio.sh"
    local files="$(find "$1" -type f -name "$2")"
    local file
    local new
    while IFS=$'\n' read -r file; do
        new="$(dirname "$file")/$3"
        get_user_input "rename $file -> $new"
        if [ $? -eq 0 ]; then
            mv "$file" "$new"
        fi

    done <<< "$files"
}

# ARRAY UTILS

# not used
is_array() {
  local var=$1
  [[ "$(declare -p $var)" =~ "declare -a" ]]
}

#Reverse order of array
#USAGE: reverse_array arrayname
reverse_array() {
    local arrayname=${1:?Array name required}
    local array
    local revarray
    local e

    #Copy the array, $arrayname, to local array
    eval "array=( \"\${$arrayname[@]}\" )"

    #Copy elements to revarray in reverse order
    for e in "${array[@]}"; do
    revarray=( "$e" "${revarray[@]}" )
    done

    #Copy revarray back to $arrayname
    eval "$arrayname=( \"\${revarray[@]}\" )"
}


#Test if value is in an array
#USAGE: array_contains arrayname
array_contains () {
    local array="$1[@]"
    local seeking=$2
    local in=1
    for element in "${!array}"; do
        if [[ $element == $seeking ]]; then
            in=0
            break
        fi
    done
    return $in
}

escape_sed() {
 sed \
  -e 's/\&/\\\&/g'
}