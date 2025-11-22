windows_entries() {
  local start_ns end_ns diff_ns
  start_ns=$(date +%s%N)

  local icon="${PARTS['windows.icon']}"
  local switch_cmd="niri msg action focus-window --id"
  local count=0

  if ${FZFLAUNCHER_NIRI_JUMP:-true}; then
    switch_cmd="$HOME/.config/fzfLauncher/niri_jump.sh"
  fi

  if ! have niri; then
    return 0
  fi

  ACTIVE=""
  INACTIVE=""
  URGENT="󰎃"
  FLOAT_ACTIVE="󰄶"
  FLOAT_INACTIVE="󰄷"
  
  #ACTIVE="#"
  #INACTIVE="o"
  #URGENT="*"
  #FLOAT_ACTIVE="^"
  #FLOAT_INACTIVE="^"

  #ACTIVE="■"
  #INACTIVE="□"
  #URGENT="!"
  #FLOAT_ACTIVE="■"
  #FLOAT_INACTIVE="□"
  #FLOAT_ACTIVE="█"
  #FLOAT_INACTIVE="·"

  get() { niri msg -j "$1" 2>/dev/null || niri msg --json "$1" 2>/dev/null || true; }


  windows="$(get windows)"
  workspaces="$(get workspaces)"


echo "$workspaces" | jq -c 'sort_by(-.id)[]' | while read -r ws; do
    # echo "workspace: $ws"

	id=$(jq -r '.id' <<< "$ws")
	idx=$(jq -r '.idx' <<< "$ws")
	# echo "$id"

	fwswindows="$(printf '%s' "$windows" | jq --arg ws_id "$id" '
    [ .[]? 
      | select((.workspace_id | tostring) == $ws_id)
	  | select(.is_floating  == true)
      | . + {order: (.layout.pos_in_scrolling_layout[0] // .layout.tile_pos_in_workspace_view[0] // 999999)}
    ] | sort_by(.order)
    ')"

	fwcount="$(printf '%s' "$fwswindows" | jq 'length')"
	# echo $fwcount
	count+=$fwcount

	index=$fwcount
	echo "$fwswindows" | jq -c 'sort_by(-.order)[]' | while read -r win; do 
		# echo $win

		# order=$(jq -r '.layout.pos_in_scrolling_layout[0]' <<< "$win" || -1)
		# focused=$(jq -r '.is_focused' <<< "$win" || false)
		# isurgent=$(jq -r '.is_urgent' <<< "$win" || false)
		# floating=$(jq -r '.is_floating' <<< "$win" || false)
		title=$(jq -r '.title' <<< "$win" || "unknown")
		app_id=$(jq -r '.app_id' <<< "$win" || "unknown")
		winid=$(jq -r '.id' <<< "$win" || "unknown")

		text="$idx | "
		for i in $(seq 1 $fwcount); do
			#if [[ "$focused" == "true" ]]; then 
			if [[ "$i" == "$index" ]]; then 
				char="$FLOAT_ACTIVE"; 
			else 
				char="$FLOAT_INACTIVE"; 
			fi

			text+="$char "
		done
		text+="                    "
		text="${text:0:20}"
		printf '%s %-20s %s\t%s\n' "$icon" "$text" "$title $app_id" "$switch_cmd $winid"

		# echo "$index"
		((index--))

	done

	wswindows="$(printf '%s' "$windows" | jq --arg ws_id "$id" '
    [ .[]? 
      | select((.workspace_id | tostring) == $ws_id)
	  | select(.is_floating  == false)
      | . + {order: (.layout.pos_in_scrolling_layout[0] // 999999)}
    ] | sort_by(.order)
    ')"

	wcount="$(printf '%s' "$wswindows" | jq 'length')"
	count+=$wcount

	# text="$id | "
	echo "$wswindows" | jq -c 'sort_by(-.order)[]' | while read -r win; do 
		# echo $win

		order=$(jq -r '.order' <<< "$win" || -1)
		# focused=$(jq -r '.is_focused' <<< "$win" || false)
		# isurgent=$(jq -r '.is_urgent' <<< "$win" || false)
		# floating=$(jq -r '.is_floating' <<< "$win" || false)
		title=$(jq -r '.title' <<< "$win" || "unknown")
		app_id=$(jq -r '.app_id' <<< "$win" || "unknown")
		winid=$(jq -r '.id' <<< "$win" || "unknown")

		text="$idx | "
		for i in $(seq 1 $wcount); do
			if [[ $i -eq $order ]]; then 
				char="$ACTIVE"; 
			else 
				char="$INACTIVE"; 
			fi

			# if [[ "$isurgent" == "true" ]]; then 
			# 	char="$URGENT"
			# fi

			text+="$char "
			
		done
		text+="                    "
		text="${text:0:20}"
		printf '%s %-20s %s\t%s\n' "$icon" "$text" "$title $app_id" "$switch_cmd $winid"

	done


	# text+="hello"
	# echo "$text"

done


  end_ns=$(date +%s%N)
  diff_ns=$(( end_ns - start_ns ))
  log "windows_entries exec-time ${diff_ns}ns"
  log "windows_entries count $count"
}
