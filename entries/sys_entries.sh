# entries/sys_entries.sh

locker_cmd() {
  if   have hyprlock; then echo "hyprlock"
  elif have swaylock; then echo "swaylock -f"
  elif have i3lock;   then echo "i3lock"
  elif have dm-tool;  then echo "dm-tool lock"
  else                     echo "loginctl lock-session"
  fi
}

sys_entries() {
  local start_ns end_ns diff_ns count=0
  start_ns=$(date +%s%N)

  local icon="${PARTS['sys.icon']}"
  local lock
  lock="$(locker_cmd)"

  {
    printf "%s  Lock\t%s\n" "$icon" "$lock"
    ((count++))
    printf "%s 󰐥 Shutdown\tsystemctl poweroff\n" "$icon"
    ((count++))
    printf "%s 󰐥 PowerOff\tsystemctl poweroff\n" "$icon"
    ((count++))
    printf "%s 󰜉 Reboot\tsystemctl reboot\n" "$icon"
    ((count++))
    printf "%s 󰜉 Restart\tsystemctl reboot\n" "$icon"
    ((count++))
    printf "%s 󰍃 Logout\tloginctl terminate-user \"%s\"\n" "$icon" "$USER"
    ((count++))
  }

  end_ns=$(date +%s%N)
  diff_ns=$(( end_ns - start_ns ))

  log "sys_entries exec-time ${diff_ns}ns"
  log "sys_entries count $count"
}
