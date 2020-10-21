# edfig
Edit your config files anywhere.
[![asciicast](https://asciinema.org/a/349938.svg)](https://asciinema.org/a/349938)

## Installation
Put `edfig.sh` to `~/bin` or `~/.local/bin` to install it locally
```
curl -S https://raw.githubusercontent.com/annahri/edfig/master/edfig.sh | tee $HOME/.local/bin/edfig > /dev/null
chmod +x $HOME/.local/bin/edfig
```
To uninstall, just delete it.

## Usage
```
Usage: 
  edfig [subcommand] [config name]
  edfig [config name]
       
Example:
  edfig add vim "$HOME/.vimrc"
  edfig vim
  edfig edit vim
  edfig rm vim
  edfig ls

Subcommands:
  add    Add new config file to list
  rm     Remove config file from list
  edit   Edit an entry
  ls     List all stored configs
  help   Print this
```
