function __edfig_entries
    set -l desc $argv[1]
    #find "$HOME/.config/edfig/configs" -type l -exec bash -c 'printf "%s\t%s\n" $(basename $0) "$1"' {} "$desc" \;
    for config in "$HOME/.config/edfig/configs"/*
        set -l basename (basename "$config")
        printf '%s\t%s\n' "$basename" "$desc"
    end
end

complete -c edfig -f -a "(__edfig_entries edit)" -d "Edits a config using EDITOR"
complete -c edfig -o r -f -a "(__edfig_entries rename)" -d "Renames a config file"
complete -c edfig -o e -f -a "(__edfig_entries edit)" -d "Edits a config using EDITOR"
complete -c edfig -o a -r -d "Adds a config file to edfig list"
complete -c edfig -o l -f -d "Show edfig list"
complete -c edfig -o h -f -d "Display usage"
