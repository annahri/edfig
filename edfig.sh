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
msg_error() { echo -e "  ${red}x$reset $1" >&2 && exit "$2"; }
msg_ok() { echo -e "  ${green}v$reset $1" >&2; }

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
# Add new config path to list
#
config_add() {
    test "$#" -ne 2 &&
        msg_error "Usage: $CMD add <name> <config path>" 8

    local name="$1"
    local path="${2:-}"
    local desc="${3:Config}"

    case "$name" in
        add|edit|rm|ls|help)
            msg_error "Reserved name. Please use another." 1
            ;;
        *)
            if [[ "${name:0:1}" =~ ^.*([!?.,])+.*$ ]]; then
                msg_error "Cannot use ${bold}${name:0:1}${reset} as the begining of name." 1
            fi
            ;;
    esac

    test -f "$path" ||
        msg_error "Not found: $path" 9

    echo -e "$name:$desc:$path" | tee -a "$config_list" > /dev/null ||
        msg_error "Cannot add new config." 7

    msg_ok "New config has been added."
    exit
}

#
# Modify specified config name and its path
# `edfig edit` with no argument will edit entire configs.list
#
config_edit() {
    local name="${1:-}"

    test -z "$name" &&
        if ! $EDITOR "$config_list" 2> /dev/null; then
            msg_error "Cannot execute $EDITOR. Exiting" 3
        fi

    awk -F: '{print $1}' "$config_list" | grep -qw "$name" ||
        msg_error "Config for ${bold}$name${reset} not found in $config_list" 1

    cleanup() { rm -f "$tempfile"; }
    trap cleanup EXIT INT QUIT

    tempfile=$(mktemp /tmp/config-XXX.tmp)
    linenum=$(grep -wn "$name" "$config_list" | cut -d: -f1)

    grep -w "$name" "$config_list" | tee "$tempfile" > /dev/null ||
        msg_error "Error ocurred." 2

    raw="$(head -1 "$tempfile")"

    $EDITOR "$tempfile" 2> /dev/null ||
        msg_error "Error on $EDITOR. Aborting" 3

    test $(grep '\S' "$tempfile" | wc -l) -ne 1 &&
        msg_error "Invalid syntax. Must not contain multiple lines." 8

    test "$raw" == "$(head -1 "$tempfile")" &&
        msg_ok "No changes." && exit

    line="$(sed 's/"/\\"/g;s/\//\\\//g' "$tempfile")"

    sed "${linenum}s/.*/$line/" "$config_list" | sponge "$config_list" ||
        msg_error "Error editing entry." 4

    msg_ok "Successfully edited."
    cleanup &&
        trap -- EXIT INT QUIT

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

    tempfile=$(mktemp /tmp/configs-XXX.tmp)

    tee "$tempfile" < "$config_list" > /dev/null ||
        msg_error "Unable to make temporary copy of $(basename $config_list)." 2


    grep -v "$line" "$tempfile" | tee "$config_list" > /dev/null ||
        msg_error "Unable to remove ${bold}$name${reset} from list" 4

    msg_ok "Successfully removed."

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
        | awk -F: '{print $1,$3,$2}' \
        | column -t \
        | awk '{print " "$1"\n  Path: "$2"\n  Desc: "$3}'

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
config_tmp="/tmp/edfig-${name}-$config_file"

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
