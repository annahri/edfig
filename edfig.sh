#!/bin/bash
#
# Edfig v1.0
# author: Muhammad Ahfas An Nahri <ahfas.annahri@gmail.com>
#

cmd=$(basename "$0")
cmd="${cmd%.sh}"

edfig_dir="${HOME}/.config/edfig"
edfig_configs_dir="${edfig_dir}/configs"
edfig_editor="${EDITOR:-vi}"

# Color codes
RESET='\033[0m'       # Reset all formatting
BOLD='\033[1m'        # Bold text

RED='\033[31m'        # Red text
GREEN='\033[32m'      # Green text
YELLOW='\033[33m'     # Yellow text
BLUE='\033[34m'       # Blue text

msg() { printf '%s\n' "$@"; }
color_msg() {
    local color="${1^^}"; shift
    printf "%b%b%s%b\n" "${BOLD}" "${!color}" "edfig: $*" "$RESET";
}
err()  { color_msg    red "$*" >&2; }
good() { color_msg  green "$*" >&2; }
warn() { color_msg yellow "$*" >&2; }

usage() {
    msg "${cmd} -- Access your frequently edited config files using alias" \
        " " \
        "USAGE:" \
        " ${cmd} -a <path> [alias]" \
        " ${cmd} -e|-d <name>" \
        " ${cmd} -r <alias> <new alias>" \
        " ${cmd} <alias>" \
        " ${cmd} -l" \
        " " \
        "OPTIONS:" \
        " -a <path> [alias]  Adds a config file to edfig list as alias (if given)"\
        "                    otherwise the basename of the config" \
        " -e <alias>         Edits the config file using EDITOR" \
        " -d <alias>         Removes the config file from list" \
        " -r <alias> <new>   Renames a config alias" \
        " -l                 Prints config list" \
        " " \
        "EXTRA:" \
        " If EDFIG_GWD environment variable is set, ${cmd} will change the CWD to the" \
        " original config's working directory." >&2
    exit
}

config_add() {
    local source="$1"
    local alias="$2"
    local type="file"

    local re='^[][*_-]'
    if echo -e "${source}\n${alias}" | grep -qE "$re"; then
        err "The source config path and/or the config name cannot starts with: - _ * [ ] characters"
        exit 1
    fi

    if [[ ! -e "$source" ]]; then
        err "The source config file/directory doesn't exist: $source "
        exit 1
    fi

    if [[ -z "$alias" ]]; then
        alias="$(basename "$source")"
    fi

    if [[ -d "$source" ]]; then
        warn "The source is a directory. Some text editor doesn't support opening a directory."
        type="directory"
    fi

    fullpath="${edfig_configs_dir}/${alias}"

    if [[ -f "$fullpath" ]]; then
        err "Config \`$alias\` already exists."
        exit 1
    fi

    ln -s "$source" "$fullpath"
    good "Config $type has been added"
}

config_delete() {
    local alias="$1"
    targetfile="${edfig_configs_dir}/${alias}"

    if [[ ! -e "$targetfile" ]]; then
        err "Config \`$alias\` doesn't exist."
        exit 1
    fi

    if ! unlink "$targetfile"; then
        err "Unable to remove $alias from list"
        err "Please check $edfig_configs_dir manually"
        exit
    fi

    good "Config \`$alias\` has been deleted from list."
}

config_edit() {
    local alias="$1"; shift
    targetfile="${edfig_configs_dir}/${alias}"

    if [[ ! -e "$targetfile" ]]; then
        err "Config \`$alias\` doesn't exist."
        exit 1
    fi

    realpath=$(readlink -f "$targetfile")
    filetype=$(get_filetype "$realpath")

    if [[ "$EDFIG_GWD" ]] && [[ "$filetype" != "d" ]]; then
        config_dir=$(dirname "$realpath")
        realname=$(basename "$realpath")

        pushd "$config_dir" &> /dev/null|| :
        "$edfig_editor" "$realname"
        popd &> /dev/null || :
        exit
    fi

    if [[ "$filetype" == "d" ]]; then
        pushd "$realpath" &> /dev/null || :
        "$edfig_editor" .
        popd &> /dev/null || :
        exit
    fi

    "$edfig_editor" "$realpath"
}

config_rename() {
    local alias="$1"
    local new_alias="$2"

    if [[ -z "$alias" ]] || [[ -z "$new_alias" ]]; then
        err "Alias name and/or the new alias name is missing."
        exit 1
    fi

    if { pushd "$edfig_configs_dir" &> /dev/null || :d
         mv "$alias" "$new_alias"
         popd &> /dev/null || :; } then
        good "$alias has been renamed to $new_alias"
        exit
    fi

    err "error occurred when renaming $alias to $new_alias"
    exit 1
}

config_list() {
    while read -r config; do
        basename=$(basename "$config")
        realpath=$(readlink -f "$config")
        filetype=$(get_filetype "$realpath")

        printf '%d %b%s%b %b%s%b %b%s%b\n' \
            "$((++i))" \
            "$GREEN" "$basename" "$RESET" \
            "$YELLOW" "$filetype" "$RESET" \
            "$BLUE" "$realpath" "$RESET"
    done < <(find "$edfig_configs_dir" -type l | sort) \
        | column -N "NO,NAME,TYPE,PATH" -t -H "TYPE"

    unset i
}

set_opt() {
    if [[ "$action" ]]; then
        err "Can only use 1 option: -${action::1}"
        exit 1
    fi

    action="$1"
}

get_filetype() {
    local path="$1"
    filetype=$(ls -ld "$path" | cut -c1)
    case "$filetype" in
        d) result="$filetype" ;;
        *) result="f" ;;
    esac
    echo "$result"
}

main() {
    # Create configs dir on the first run only
    if [[ ! -d "$edfig_configs_dir" ]]; then
        mkdir -p "$edfig_configs_dir"
    fi

    if [[ $# -eq 0 ]]; then
        usage
    fi

    while [[ $# -ne 0 ]]; do case "$1" in
        -h) usage            ;;
        -a) set_opt "add"    ;;
        -e) set_opt "edit"   ;;
        -d) set_opt "delete" ;;
        -r) set_opt "rename" ;;
        -l) set_opt "list"   ;;
         *) params+=("$1")   ;;
    esac; shift; done

    if [[ -z "${action}" ]]; then
        names=$(find "$edfig_configs_dir" -type l -exec basename {} \;)

        if echo "$names" | grep -wq -- "${params[0]}"; then
            config_edit "${params[0]}"
            exit
        fi

        err "Invalid option or Config not found: ${params[*]}"
        exit 1
    fi

    "config_${action}" "${params[@]}"
}

main "$@"
