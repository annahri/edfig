function __edfig_entries
    grep -v '^#' "$HOME/.config/configs.list" | awk -F= '{print $1}' | awk '{$1=$1}1' | sort
end

complete -x -c edfig -d "Config" -a "(__edfig_entries)"

complete -c edfig -a add -d "Adds a config"
complete -c edfig -a rm -d "Removes a config"
complete -c edfig -a ls -d "Lists all stored configs"
complete -c edfig -a edit -d "Edits an entry"
complete -c edfig -a help -d "Prints help"
