# Edfig - Edit Config

A simple utility to manage and quickly access frequently edited config files. Assign easy aliases to your configs for swift access.

## Usage

```
# Add config file or directory
edfig -a /path/to/config [alias]

# Access the config file using alias
edfig -e <alias>
# or
edfig <alias>

# Remove config file
edfig -d <alias>

# Rename a config alias
edfig -r <alias> <new alias>

# List config aliases
edfig -l
```

## Installation

```sh
curl -sLo ~/.local/bin/edfig https://raw.githubusercontent.com/annahri/edfig/main/edfig.sh
chmod +x ~/.local/bin/edfig
```

## Requirements

- Bash

