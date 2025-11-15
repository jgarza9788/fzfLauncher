<h1 style="
  font-family: 'JetBrains Mono', monospace;
  font-size: 3rem;
  color: #00ff55;
  /* background: #050608; */
  padding: 20px;
  /* display: inline-block; */
  text-shadow:
    0 0 2px #00ff55,
    0 0 4px #00ff55,
    0 0 8px #00ff55;
  letter-spacing: 0.12em;
">
  𝚏𝚣𝚏𝙻𝚊𝚞𝚗𝚌𝚑𝚎𝚛
</h1>


[![Watch the video](https://img.youtube.com/vi/59FWX5HcL70/maxresdefault.jpg)](https://www.youtube.com/watch?v=59FWX5HcL70)


---

`fzfLauncher` is a fuzzy launcher script ( based on [fsel](https://github.com/Mjoyufull/fsel) ) for Linux / Wayland (with first-class Niri support).  
It lets you drive almost everything from one fzf menu:

- 🪟 Switch between **Niri windows**
- 🧩 Launch **apps** (.desktop + flatpak)
- 🕒 Search **shell history** (fish / zsh / bash)
- 🌐 Open **web shortcuts** in app mode
- 📋 Browse and re-copy **clipboard history**
- ⚙️ Run **system commands** (lock, reboot, shutdown, logout)
- ⭐ Run your own **custom commands**

The UI is driven by `fzf` and everything is just `label<TAB>command` under the hood.

---

## Table of Contents
- [Table of Contents](#table-of-contents)
- [Support](#support)
- [Requirements](#requirements)
  - [🔤 Recommended: Install a Nerd Font](#-recommended-install-a-nerd-font)
- [Installation](#installation)


---

## Support
[Buy Me ☕](https://buymeacoffee.com/jgarza97885)  
... or just support one of the other projects below.


---

## Requirements

* Bash 
	* (script uses `bash` features + `set -euo pipefail`)
* [`fzf`](https://github.com/junegunn/fzf)
* For Niri integration:
  * [`niri`](https://github.com/YaLTeR/niri`)
  * Optional: `jq` for JSON IPC (falls back to `awk` if missing)
* For app launching:
  * Standard `.desktop` directories:
    `~/.local/share/applications`, `/usr/share/applications`, `/var/lib/snapd/desktop/applications`
  * Optional: `flatpak` for Flatpak app entries
* For clipboard integration:
  * Preferred: `cliphist` + `wl-copy`
  * Or: `wl-paste-history`
  * Or (no history): `xclip`
* For system actions:
  * One or more of: `hyprlock`, `swaylock`, `i3lock`, `dm-tool`, `loginctl`
* A terminal emulator: `kitty`, `alacritty`, `footclient`, `gnome-terminal`, `konsole`, or `xterm`

### 🔤 Recommended: Install a Nerd Font

`fzfLauncher` uses many glyph icons (apps, windows, history, clipboard, system icons).  
To ensure the UI looks correct inside your terminal, **a Nerd Font is strongly recommended**.

Best choices:

- **JetBrainsMono Nerd Font** (recommended)
- FiraCode Nerd Font
- Caskaydia Cove (Cascadia Code) Nerd Font
- Hack Nerd Font

Download: https://www.nerdfonts.com/font-downloads

If icons appear as empty squares, your terminal is not using a Nerd Font.

---

## Installation

1. This is a B.O.B. (Bunch of Bash)
  * so put the files where you want. 
    * please note the paths to the files will change

2. add to niri config

  * Hot Keys
```json
//Z for Ze windows!
Mod+Z       { spawn "~/.config/fzfLauncher/launchWINDOWS.sh";}

//X for everything
Mod+X       { spawn "~/.config/fzfLauncher/launchALL.sh";}

//space for everything except for clipboard
Mod+Space   { spawn "~/.config/fzfLauncher/launchFAST.sh";}

//A for Apps
Mod+A       { spawn "~/.config/fzfLauncher/launchAPPS.sh";}

// Clipboard - V for the clipboard
Mod+V    { spawn "~/.config/fzfLauncher/launchCLIPBOARD.sh";}
```

  * Add windows rules
    * this will make sure the fzflauncher appears in floating mode
```json
window-rule {
    match app-id=r#"kitty$"# title="^fzfLauncher$"
    open-floating true

}

window-rule {
    match app-id=r#"kitty$"# title="^Clipboard$"
    open-floating true

}

```

