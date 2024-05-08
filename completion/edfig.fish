function __edfig_entries
    set -l desc $argv[1]
    #find "$HOME/.config/edfig/configs" -type l -exec bash -c 'printf "%s\t%s\n" $(basename $0) "$1"' {} "$desc" \;
    for config in "$HOME/.config/edfig/configs"/*
        set -l basename (basename "$config")
        printf '%s\t%s\n' "$basename" "$desc"
    end
end

function __edfig_entries
    find ~/.config/edfig/configs -type l -exec basename {} \;
end

set -l edfig_subcommands a ad add del rm re ren rename l ls list help

complete -f -c edfig -n "not __fish_seen_subcommand_from (__edfig_entries); and not __fish_seen_subcommand_from $edfig_subcommands" -a "(__edfig_entries) $edfig_subcommands"

complete    -c edfig -n "not __fish_seen_subcommand_from $edfig_subcommands" -a "a ad add" -d "Add a config file to list as an alias"
complete -f -c edfig -n "not __fish_seen_subcommand_from $edfig_subcommands" -a "re ren rename" -d "Rename an alias"
complete -f -c edfig -n "not __fish_seen_subcommand_from $edfig_subcommands" -a "del rm" -d "Remove an alias"
complete -f -c edfig -n "not __fish_seen_subcommand_from $edfig_subcommands" -a "l ls list" -d "List aliases"
complete -f -c edfig -n "not __fish_seen_subcommand_from $edfig_subcommands" -a "help" -d "Show help"

set -l edfig_subcommands_aliasonly re ren rename del rm
complete -f -c edfig -n "__fish_seen_subcommand_from $edfig_subcommands_aliasonly; and not __fish_seen_subcommand_from (__edfig_entries)" -a "(__edfig_entries)"
