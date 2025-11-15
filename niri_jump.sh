
id=$1
niri msg action open-overview
sleep 0.1
niri msg action focus-window --id $id
sleep 0.1
niri msg action close-overview