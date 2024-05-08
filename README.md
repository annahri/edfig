# Edfig - Edit Config

A simple utility to manage and quickly access frequently edited config files. Assign easy aliases to your configs for swift access.

## Usage

```
# Add config file or directory
edfig a|ad|add /path/to/config [alias]

# Access the config file using alias
edfig <alias>

# Remove config file
edfig del|rm <alias>

# Rename a config alias
edfig re|ren|rename <alias> <new alias>

# List config aliases
edfig l|ls|list
```

## Installation

```sh
curl -sLo ~/.local/bin/edfig https://raw.githubusercontent.com/annahri/edfig/main/edfig
chmod +x ~/.local/bin/edfig
```

## Requirements

- Bash

