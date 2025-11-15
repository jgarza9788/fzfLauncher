
dirs=$1
app_cache=$2


# if (( $(date +%s) - $(stat -c %Y "$app_cache") > 10 )); then
#   echo "File is older than 10 seconds"
# else
#   echo "File is NOT older than 10 seconds"
#   exit 
# fi

if [[ -e "$app_cache.temp" ]]; then
    echo "app_cache.temp exists, exit for now"
    exit
fi


# Convert colon-separated string into array
IFS=':' read -ra dir_array <<< "$dirs"

have() { 
    command -v "$1" >/dev/null 2>&1; 
}

create_temp() {
  for d in "${dir_array[@]}"; do
    [[ -d "$d" ]] || continue
    find "$d" -maxdepth 1 -type f -name "*.desktop"
  done \
  | while IFS= read -r desk; do
      id="$(basename "$desk" .desktop)"
      name="$(grep -m1 -E '^Name=' "$desk" | sed 's/^Name=//' || true)"
      [[ -z "$name" ]] && name="$id"

      exec="$(grep -m1 -E '^Exec=' "$desk" | sed 's/^Exec=//' || true)"
      exec="$(printf '%s' "$exec" | sed -E 's/ *%[fFuUdDnNickvm]//g')"

      printf '%s\t%s\n' "$name" "$exec"
    done \
  | awk -F'\t' '!seen[$2]++' > "$app_cache.temp"
  
  # let's also add the flatpaks
  if have flatpak; then
    flatpak list --app --columns=name,application \
    | tail -n +1 \
    | while IFS=$'\t' read -r name appid; do
        printf "%s\tflatpak run %s\n" "$name" "$appid"
    done \
    | awk -F'\t' '!seen[$2]++' >> "$app_cache.temp"
  fi 
  
}

create_temp
sleep 1.0
mv "$app_cache.temp" "$app_cache"


