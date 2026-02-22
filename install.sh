#!/usr/bin/env bash
set -euo pipefail

mkdir -p ~/.local/bin ~/.config/fzfl ~/.cache/fzfl
chmod +x ~/.local/bin/

cp ./webapps.tsv ~/.config/fzfl
cp ./config.sh ~/.config/fzfl
cp ./fzfl.sh ~/.local/bin

chmod +x ~/.local/bin/fzfl.sh


