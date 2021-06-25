#! /usr/bin/env bash
# edfig.sh -- Config file manager
# @annahri

set -o nounset

config_list="$HOME/.config/edfig.list"
CMD="${0##*/}"
EDITOR="${EDITOR:-vi}"

short_usage() {
    echo -e "${bold}Usage:${reset} $CMD [subcommand|name] [...]"
}

usage() {
    short_usage
    echo -e >&2
    echo -e "${bold}Subcommands:${reset}" >&2
    echo -e "  ${bold}add${reset}    Add new config file to list" >&2
    echo -e "  ${bold}rm${reset}     Remove config file from list" >&2
    echo -e "  ${bold}edit${reset}   Edit an entry" >&2
    echo -e "  ${bold}ls${reset}     List all stored configs" >&2
    echo -e "  ${bold}help${reset}   Print this" >&2
    echo -e >&2
    echo -e "${bold}Example:${reset}" >&2
    echo -e "  $CMD add vim \"\$HOME/.vimrc\"" >&2
    echo -e "  $CMD vim" >&2
    echo -e "  $CMD edit vim" >&2
    echo -e "  $CMD rm vim" >&2
    echo -e "  $CMD ls" >&2
    echo -e >&2
    echo -e "$CMD is a command line tool to ease config files editing" >&2
    exit
}

#=============================================================
# Colors
#=============================================================
bold='\e[1m'
red='\033[1;31m'
green='\033[1;32m'
reset='\033[0m'
#=============================================================

#=============================================================
# Helper Functions
#=============================================================
msg_error() { echo -e "  ${red}x$reset $1" >&2 && exit "${2:-1}"; }
msg_ok() { echo -e "  ${green}v$reset $1" >&2; }
#=============================================================

#=============================================================
# Tests functions
#=============================================================
#
# Check if 'name' exists
#
nameExists() {
    local name="$1"
    grep -qw "$name" <(cut -d: -f1 "$config_list")
}
#=============================================================

#=============================================================
# Edfig main functions
#=============================================================
#
# Get config file path from the specified config name
#
config_getPath() {
    awk -F: "/${1}:/{print \$3}" "$config_list"
}

#
# Checks the config file formatting
# config_name:blank:config_path
#
config_check() {
    OLDIFS=$IFS
    IFS=$'\n'
    local input=($1)
    IFS=$OLDIFS
    # 1. Name must not contain : character
    # 2. A config line should respect the predefined format
    # 3. Name and path filed cannot null
    # 4. Specified path should exist
    for line in "${input[@]}"; do
        _separators=$(echo "$line" | grep -o ':' | wc -l)
        _name=$(echo "$line" | cut -d: -f1)
        _path=$(echo "$line" | cut -d: -f3)

        if test $_separators -ne 2; then
            msg_error "Formatting error: \"$line\"" 11
        fi

        if test -z "$_name" || test -z "$_path"; then
            msg_error "Name or path cannot be empty." 10
        fi

        if grep -q ":" <<< "$_name" || grep -q ":" <<< "$_path"; then
            msg_error "Name or path must not contain character :" 12
        fi

        if ! test -f "$_path"; then
            msg_error "Error: \"$_path\" doesn't exist" 14
        fi

        unset _name _path
    done
}

#
# Add new config path to list
#
config_add() {
    test "$#" -ne 2 &&
        msg_error "Usage: $CMD add <name> <config path>" 8

    local name="$1"
    local path="${2:-}"
    local desc="${3:-Config}"

    # Config name tests
    test $(echo "$name" | grep -c '$') -eq 1 ||
        msg_error "Config name must not contain newlines." 9

    nameExists "$name" &&
        msg_error "Config name $name already exists." 1

    case "$name" in
        add|edit|rm|ls|help)
            msg_error "Reserved name. Please use another." 1
            ;;
        -*)
            msg_error "Cannot use dash as the leading character. It might reserved." 1
            ;;
        *:*)
            msg_error "Config name must not contain :" 1
            ;;
        *)
            if [[ "${name:0:1}" =~ ^.*([!?.,])+.*$ ]]; then
                msg_error "Cannot use ${bold}${name:0:1}${reset} as the begining of name." 1
            fi

            awk -F: /
            ;;
    esac

    path=$(readlink -f "$path")

    test -f "$path" ||
        msg_error "Not found: $path" 9

    echo -e "$name:$desc:$path" | tee -a "$config_list" > /dev/null ||
        msg_error "Cannot add new config." 7

    msg_ok "$name has been added to config list."
    exit
}

#
# Modify specified config name and its path
# `edfig edit` with no argument will edit entire configs.list
#
config_edit() {
    local name="${1:-}"

    cleanup() { rm -f "$tempfile"; }
    trap cleanup EXIT INT QUIT

    tempfile=$(mktemp -t config-XXX.tmp)

    # Get the line of the specified config. Otherwise, skip
    if test -n "$name"; then
        nameExists "$name" ||
            msg_error "Config for ${bold}$name${reset} not found in $config_list" 1

        grep -w "$name" "$config_list" | tee "$tempfile" > /dev/null ||
            msg_error "Error ocurred." 2

        linenum=$(grep -wn "$name" "$config_list" | cut -d: -f1)
    else
        cp "$config_list" "$tempfile" 2> /dev/null ||
            msg_error "Cannot create temporary file." 2
    fi

    # Unedited tempfile get stored in raw.
    raw="$(cat "$tempfile" | grep -v '^$')"

    if $EDITOR "$tempfile" 2> /dev/null; then
        grep -v '^$' "$tempfile" | sort | sponge "$tempfile"
    else
        msg_error "Unexpected error on $EDITOR. Aborting" 3
    fi

    diff <(echo "$raw") <(cat "$tempfile") > /dev/null 2>&1 &&
        msg_ok "No changes." && exit

    if test -z "$name"; then
        # New/modified lines `comm -13 $config_list $tempfile`
        # Deleted lines `comm -23 $config_list $tempfile`
        modified_lines=$(comm -13 "$config_list" "$tempfile" 2> /dev/null | sed 's/"/\\"/g;s/\//\\\//g')
        deleted=$(comm -23 "$config_list" "$tempfile" 2> /dev/null | cut -d: -f1 | xargs)

        config_check "$modified_lines"

        mv "$tempfile" "$config_list" 2> /dev/null ||
            msg_error "Error applying changes." 4

        name=$(echo "$modified_lines" | cut -d: -f1 | xargs)
    else
        if test $(grep -c '\S' "$tempfile") -gt 1; then
            msg_error "Invalid syntax. Must not contain multiple lines." 8
        fi

        line="$(sed 's/"/\\"/g;s/\//\\\//g' "$tempfile")"
        config_check "$line"

        sed "${linenum}s/.*/$line/" "$config_list" | sponge "$config_list" ||
            msg_error "Error editing entry." 4
    fi


    msg_ok "Successfully edited ${bold}$name${reset}."

    test -n "${deleted:-}" &&
        msg_ok "Successfully deleted: ${bold}$deleted${reset}"

    exit
}

#
# Delete a config from list
#
config_rm() {
    local name="${1:-}"
    test "$name" ||
        msg_error "What to remove?" 1

    line=$(awk -F: -v name="$name" '$1 == name' "$config_list")

    test "$line" ||
        msg_error "Config for ${bold}$name${reset} not found in $config_list" 1

    cleanup() { rm -f "$tempfile"; }
    trap cleanup EXIT INT QUIT

    tempfile=$(mktemp -t configs-XXX.tmp)

    tee "$tempfile" < "$config_list" > /dev/null ||
        msg_error "Unable to make temporary copy of $(basename $config_list)." 2


    grep -v "$line" "$tempfile" | tee "$config_list" > /dev/null ||
        msg_error "Unable to remove ${bold}$name${reset} from list" 4

    msg_ok "Successfully removed $name from list."

    cleanup &&
        trap -- EXIT INT QUIT

    exit
}

#
# List all stored configs
#
config_ls() {
    echo -e "${bold}Stored Configs:${reset}"
    grep -v '^#' "$config_list" \
        | sort \
        | awk -F: '{print $1,$3}' \
        | column -t \
       # | awk '{print " "$1"\n  Path: "$2"\n  Desc: "$3}'

    exit
}

#=============================================================

#
# Begin Script, argument parsing
#
test "$#" -eq 0 &&
    short_usage && exit

case "$1" in
    add|rm|edit|ls)
        _cmd="$1"; shift
        config_${_cmd} "$@"
        ;;
    help|-h|--help) usage ;;
    *) name="$1" ;;
esac

test -s "$config_list" ||
    msg_error "$config_list doesn't exist or is empty. Try adding something first.\n edfig add <name> <path>" 13

#
# Get config path and check if it's existed
#
config_path=$(config_getPath "$name")
test "$config_path" ||
    msg_error "${bold}$name${reset} doesn't exist in configs list." 1

#
# Trap EXIT QUIT INT signal to clean temporary file
#
cleanup() { rm -f "$config_tmp"; }
trap cleanup EXIT QUIT INT

config_file="${config_path##*/}"
config_tmp="${TMPDIR:-/tmp}/edfig-${name}-$config_file"

cp "$config_path" "$config_tmp" 2> /dev/null ||
    msg_error "Error creating temporary file. Aborting" 10

$EDITOR "${config_tmp}" 2> /dev/null ||
    msg_error "Cannot execute $EDITOR. Exiting" 3

diff "$config_tmp" "$config_path" &> /dev/null &&
    msg_ok "No changes." && exit

tee "$config_path" < "$config_tmp" > /dev/null ||
    msg_error "Cannot save changes. Aborting" 11

msg_ok "Saving changes."

cleanup && exit
