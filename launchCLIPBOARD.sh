#!/usr/bin/env bash
kitty --title "Clipboard" -e fish -c '~/.config/fzfLauncher/fzfLauncher.sh --mode clipboard --hist-limit 0 --clipboard-limit 300'