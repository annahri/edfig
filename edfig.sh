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
edfig_commands="a|ad|add|l|ls|list|rm|del|re|ren|rename"

# Color codes
RESET=$(tput sgr0)       # Reset all formatting
BOLD=$(tput bold) # Bold text

RED=$(tput setaf 1) # Red text
GREEN=$(tput setaf 2) # Green text
YELLOW=$(tput setaf 3) # Yellow text
BLUE=$(tput setaf 4) # Blue text

msg() { printf '%s\n' "$@"; }
color_msg() {
    local color="${1^^}"; shift
    printf "%b%b%s%b\n" "${BOLD}" "${!color}" "edfig: $*" "$RESET";
}
err()  { color_msg    red "$*" >&2; }
good() { color_msg  green "$*" >&2; }
warn() { color_msg yellow "$*" >&2; }

usage() {
    msg "${BOLD}${cmd}${RESET} -- Access your frequently edited config files using alias" \
        " " \
        "${BOLD}USAGE:${RESET}" \
        "  ${BOLD}${cmd} add <path> [alias]${RESET}" \
        "  ${BOLD}${cmd} del <name>${RESET}" \
        "  ${BOLD}${cmd} rename <alias> <new alias>${RESET}" \
        "  ${BOLD}${cmd} ls${RESET}" \
        "  ${BOLD}${cmd} <alias>${RESET}" \
        " " \
        "${BOLD}SUBCOMMANDS:${RESET}" \
        "  ${BOLD}a|ad|add <path> [alias]${RESET}" \
        "    Adds a config file to edfig list as alias (if given) otherwise the basename of the config" \
        "  ${BOLD}del|rm <alias>${RESET}" \
        "    Removes the config file from list" \
        "  ${BOLD}re|ren|rename <alias> <new>${RESET}" \
        "    Renames a config alias" \
        "  ${BOLD}l|ls|list${RESET}" \
        "    Prints config list" \
        "  ${BOLD}help${RESET}" \
        "    Display this help" \
        " " \
        "${BOLD}EXTRA:${RESET}" \
        "  If ${BOLD}EDFIG_GWD${RESET} environment variable is set, ${cmd} will change the CWD to the" \
        "  original config's working directory." >&2
    exit
}

check_alias() {
    echo "${1}" | grep -qE "^($edfig_commands)$" || return

    err "Alias cannot use reserved keywords: $edfig_commands"
    exit 1
}

config_add() {
    local source="$1"
    local alias="$2"
    local type="file"

    if [[ "$#" -eq 0 ]]; then 
        err "Subcommand \`add\` requires a file path: $cmd add <path> [alias]"
        exit 1
    fi

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

    check_alias "$alias"

    if [[ -d "$source" ]]; then
        warn "The source is a directory. Some text editor doesn't support opening a directory."
        type="directory"
    fi

    fullpath="${edfig_configs_dir}/${alias}"

    if [[ -f "$fullpath" ]]; then
        err "Config \`$alias\` already exists."
        exit 1
    fi

    source=$(readlink -f "$source")

    ln -s "$source" "$fullpath"
    good "$alias ($type) has been added"
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

    alias_realpath="${edfig_configs_dir}/${alias}"

    if [[ ! -e "$alias_realpath" ]]; then
        err "Alias $alias doesn't exist"
        exit 1
    fi

    check_alias "$new_alias"

    if { pushd "$edfig_configs_dir" &> /dev/null || :
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

        color=BLUE 
        if [[ $filetype == "d" ]]; then 
            color=YELLOW
            realpath="${realpath} (dir)"
        fi

        printf '%b%s%b\t%b%s%b\n' \
            "$GREEN" "$basename" "$RESET" \
            "${!color}" "$realpath" "$RESET"
    done < <(find "$edfig_configs_dir" -type l | sort) \
        | column -N "Alias,Source" -t -s $'\t'
}

set_opt() {
    if [[ "$action" ]]; then
        err "Can only use 1 option: ${action}"
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
        a|ad|add)      set_opt "add"    ;;
        del|rm)        set_opt "delete" ;;
        re|ren|rename) set_opt "rename" ;;
        l|ls|list)     set_opt "list"   ;;
        help)   usage            ;;
        *)      params+=("$1")   ;;
    esac; shift; done

    if [[ -z "${action}" ]]; then
        names=$(find "$edfig_configs_dir" -type l -exec basename {} \;)

        if echo "$names" | grep -wq -- "${params[0]}"; then
            config_edit "${params[0]}"
            exit
        fi

        err "Invalid subcommand/Config not found: ${params[*]}"
        exit 1
    fi

    "config_${action}" "${params[@]}"
}

main "$@"
