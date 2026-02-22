

```
~/.local/bin/fzfl                 # main entry
~/.local/lib/fzfl/
  sources/
    apps.sh
    web.sh
    history.sh
    clip.sh
    win_niri.sh
  cache/
    apps_cache.sh
    history_cache.sh
  lib.sh                          # shared helpers (config, cache, logging)
~/.config/fzfl/config             # shell-sourced config
~/.config/fzfl/webapps.tsv
~/.cache/fzfl/
  apps.tsv
  history.tsv
```

## Install required dependencies:
fzf
jq
wl-clipboard
cliphist

## run this to watch copy

add this to the niri config 
```
spawn-at-startup "sh" "-c" "wl-paste --type text --watch cliphist store"
```
* or run it as a service or something


## launch with kitty or whatever terminal you want

```
kitty -e fzfl.sh
```

### i like launching it like this

* within niri binds
```
Alt+Space {spawn "kitty" "-e" "--title=fzfl" "fzfl.sh"; }
```

* and a windows rule
```
// my window rules
window-rule {
    match app-id=r#"kitty$"# title="^fzfl$"
    open-floating true
}
```



##