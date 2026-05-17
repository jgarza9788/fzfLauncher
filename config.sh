# ~/.config/fzfl/config

# fzfl config (bash-sourced)

# Terminal selection: kitty | gnome-terminal | alacritty
FZFL_TERMINAL="kitty"


# Terminal run templates (supports all three)
# Use {cmd} placeholder; it will be replaced safely.
#FZFL_TERM_KITTY=(kitty --hold sh -lc "{cmd}")
#FZFL_TERM_KITTY=(kitty --hold zsh -lc "{cmd}")
#FZFL_TERM_GNOME=(gnome-terminal -- bash -lc "{cmd}")
#FZFL_TERM_ALACRITTY=(alacritty -e bash -lc "{cmd}")

# Browser (default)
#FZFL_BROWSER="chromium"
FZFL_BROWSER="chrome"

# Web launch mode: window | app
# FZFL_WEB_MODE="window"
FZFL_WEB_MODE="app"

# Edit-before-run for HIST: 0/1
FZFL_EDIT_BEFORE_RUN="0"

# Caching (seconds)
FZFL_CACHE_TTL_APPS=$((24*60*60*7))      # 7 days
FZFL_CACHE_TTL_HISTORY=$((24*60*60*1))   # 1 day

# Sources toggles
FZFL_ENABLE_APPS="1"
FZFL_ENABLE_WEB="1"
FZFL_ENABLE_HIST="1"
FZFL_ENABLE_CLIP="1"
FZFL_ENABLE_WIN="1"


#LABELS 
FZFL_LABEL_APPS="󰀻 "
FZFL_LABEL_WEB="󰖟 "
FZFL_LABEL_WIN=" "
FZFL_LABEL_CLIP="󰅎 "
FZFL_LABEL_HIST="󰋚 "


# FZFL_LABEL_APPS="[APP]"
# FZFL_LABEL_WEB="[WEB]"
# FZFL_LABEL_WIN="[WIN]"
# FZFL_LABEL_CLIP="[CLP]"
# FZFL_LABEL_HIST="[HIS]"


FZFL_WIN_JUMP="1"

FZFL_CLIP_MAX="250"


# Optional: extra app dirs (colon-separated)
FZFL_EXTRA_APP_DIRS=""
