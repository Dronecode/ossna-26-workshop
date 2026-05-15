#!/usr/bin/env bash
# workshop-tmux: launch a preconfigured tmux layout for the OSSNA 2026
# PX4 + ROS 2 workshop.
#
# Creates one named session ('ossna') with two windows:
#
#   sim     - a 5-pane layout where each of the four long-running
#             foreground processes (gazebo / px4 / common.launch.py /
#             example launch) gets its own pane, plus a tall pane on
#             the right for QGroundControl.
#
#                 ┌─────────────┬─────────────┐
#                 │ 0: gazebo   │ 1: px4      │
#                 ├─────────────┤             │
#                 │ 3: common   │ 2: qgc      │
#                 ├─────────────┤             │
#                 │ 4: example  │             │
#                 └─────────────┴─────────────┘
#
#             Each pane is pre-seeded with comment-only hint lines
#             showing the command you would paste there. The script
#             does not start anything for you — you still copy-paste
#             the actual commands from the workshop docs, but now into
#             ONE terminal window.
#
#   scratch - empty pane for ad-hoc `ros2 topic echo`, `ros2 node list`,
#             editing files with vim/nano, etc.
#
# If the session already exists this just reattaches to it.

set -eu

SESSION="ossna"

if tmux has-session -t "${SESSION}" 2>/dev/null; then
    exec tmux attach -t "${SESSION}"
fi

# Start the 'sim' window with the first pane. Creating the session also
# starts the tmux server, so subsequent `set -g` (which target the
# server/session) work.
tmux new-session -d -s "${SESSION}" -n sim

# --- Friendlier defaults ---
tmux set -g pane-border-status top
tmux set -g history-limit 20000
tmux setw -g mode-keys vi
tmux set -g status-interval 1                # refresh status bar (and animations) every second
tmux set -g default-terminal "tmux-256color" # opt into 256/truecolor where supported
tmux set -ga terminal-overrides ",xterm-256color:Tc"   # tell tmux the outer terminal is true-color
tmux set -g pane-border-lines heavy          # thicker borders on tmux 3.2+

# NOTE: mouse mode is deliberately OFF.
# With `mouse on`, tmux captures click-drag and you cannot select text with
# the mouse in the usual terminal way. Leaving it off lets attendees use
# their terminal's native click-drag → copy. The trade-off is no click-to-
# focus on panes — use Ctrl-b arrow / `Ctrl-b q <n>` to switch panes
# instead. Enable per-session with `tmux set mouse on` if you prefer.
tmux set -g mouse off

# --- Dracula-inspired palette (synthwave-y, dev-friendly) ---
#   bg     #282a36   bg-dark  #13111c
#   pink   #ff79c6   purple   #bd93f9   cyan #8be9fd
#   green  #50fa7b   yellow   #f1fa8c   orange #ffb86c
#   red    #ff5555   fg       #f8f8f2   comment #6272a4
tmux set -g status-style              "bg=#13111c,fg=#f8f8f2"
tmux set -g message-style             "bg=#ff79c6,fg=#13111c,bold"
tmux set -g pane-border-style         "fg=#3a3a5a"               # dim border for inactive
tmux set -g pane-active-border-style  "fg=#ff79c6,bold"          # hot pink for the active pane

# Pane title in the border: hex-bullets in cyan + bold pink name.
# Active pane gets a brighter title via pane-active-border-style colour, the
# format string itself is the same for all panes.
tmux set -g pane-border-format " #[fg=#8be9fd,bold]⬢#[default] #[fg=#ff79c6,bold]#{pane_title}#[default] #[fg=#8be9fd,bold]⬢#[default] "

# Window list in the status bar (powerline-ish flat segments)
tmux setw -g window-status-style           "fg=#6272a4"
tmux setw -g window-status-current-style   "fg=#13111c,bold,bg=#8be9fd"
tmux setw -g window-status-format          "  #I⋅#W  "
tmux setw -g window-status-current-format  "  #I⋅#W  "
tmux setw -g window-status-separator       ""

# Flash window name yellow when an inactive window has new output
tmux set -g monitor-activity on
tmux set -g visual-activity off
tmux setw -g window-status-activity-style  "fg=#f1fa8c,bold,blink"

# --- Animations ---
# status-left: synthwave title with a traveling "scanner" highlight that
#              sweeps across the text twice per second (workshop-banner
#              emits the tmux format string).
# status-right: 5-bar EQ visualiser + cyan workshop label + magenta clock.
tmux set -g status-left-length 60
tmux set -g status-right-length 80
tmux set -g status-left  "#(workshop-banner) "
tmux set -g status-right "#[fg=#6272a4]┤ #(workshop-spinner) #[fg=#8be9fd,bold]workshop #[fg=#6272a4]│ #[fg=#bd93f9,bold]%H:%M:%S #[fg=#6272a4]├"

# Make the prefix indicator obvious when prefix is held
tmux set -g status-keys vi

# Build the 5-pane layout described in the header comment. Use stable
# pane IDs (#{pane_id}, %0/%1/...) instead of numeric pane_index because
# tmux re-numbers pane_index in reading order whenever the layout
# changes, which would scramble titles applied after all splits.

# Pane 0 is the existing pane we got from new-session.
GZ_PANE="$(tmux display-message -p -t "${SESSION}:sim" '#{pane_id}')"

# Split horizontally → new pane on the right = px4
PX4_PANE="$(tmux split-window -h -p 50 -t "${GZ_PANE}" -PF '#{pane_id}')"

# Split the right column vertically → new pane below = qgc (taking the
# bottom ~67% so QGC has more room than its tiny pane 1 sibling).
QGC_PANE="$(tmux split-window -v -p 67 -t "${PX4_PANE}" -PF '#{pane_id}')"

# Split the left column (gazebo) vertically → new pane below for common.
COMMON_PANE="$(tmux split-window -v -p 67 -t "${GZ_PANE}" -PF '#{pane_id}')"

# Split the common pane vertically → new pane below = example launch.
EXAMPLE_PANE="$(tmux split-window -v -p 50 -t "${COMMON_PANE}" -PF '#{pane_id}')"

# Title every pane by stable ID (titles render in the pane border
# thanks to the `pane-border-status top` option set above).
tmux select-pane -t "${GZ_PANE}"      -T "gazebo"
tmux select-pane -t "${PX4_PANE}"     -T "px4"
tmux select-pane -t "${QGC_PANE}"     -T "qgc"
tmux select-pane -t "${COMMON_PANE}"  -T "ros2 common.launch.py"
tmux select-pane -t "${EXAMPLE_PANE}" -T "ros2 example launch"

# Seed each pane with a single hint. We use `clear; printf` (one command)
# rather than a sequence of `send-keys ... Enter ... Enter ...` so the
# pane shows ONE shell prompt at the end instead of one prompt per line.
# The pink/cyan ANSI escapes pick up the same Dracula palette as the rest
# of the session.
seed() {
    local target="$1"
    local payload="$2"
    tmux send-keys -t "${target}" "clear; printf '${payload}'" Enter
}

# %s escapes: \\033 (ESC), \\n (newline). The whole string is single-quoted
# inside the seed() call so bash does not interpret anything.
seed "${GZ_PANE}" \
'\033[38;5;213m▙▟ Gazebo Harmonic ▙▟\033[0m\n\033[38;5;245mSpawn the physics world. Paste:\033[0m\n\033[38;5;87m  python3 /home/ubuntu/PX4-gazebo-models/simulation-gazebo \\\n    --model_store /home/ubuntu/PX4-gazebo-models/ --world default\033[0m\n'

seed "${PX4_PANE}" \
'\033[38;5;213m▙▟ PX4 v1.16 SITL ▙▟\033[0m\n\033[38;5;245mOnce Gazebo is up, paste (4001 = x500):\033[0m\n\033[38;5;87m  PX4_GZ_STANDALONE=1 PX4_SYS_AUTOSTART=4001 \\\n    PX4_PARAM_UXRCE_DDS_SYNCT=0 \\\n    /home/ubuntu/px4_sitl/bin/px4 -w /home/ubuntu/px4_sitl/romfs\033[0m\n'

seed "${QGC_PANE}" \
'\033[38;5;213m▙▟ QGroundControl v5.0.8 ▙▟\033[0m\n\033[38;5;245mNeeds an X11-enabled container (default for ./docker/docker_run.sh).\033[0m\n\033[38;5;87m  /home/ubuntu/QGroundControl/qgroundcontrol\033[0m\n'

seed "${COMMON_PANE}" \
'\033[38;5;213m▙▟ ROS 2 :: common.launch.py ▙▟\033[0m\n\033[38;5;245mXRCE-DDS agent + clock/foxglove bridges + robot_state_publisher + px4_tf + static TF:\033[0m\n\033[38;5;87m  ros2 launch px4_ossna_26 common.launch.py\033[0m\n'

seed "${EXAMPLE_PANE}" \
'\033[38;5;213m▙▟ ROS 2 :: example launch ▙▟\033[0m\n\033[38;5;245mPick ONE once common.launch.py is up:\033[0m\n\033[38;5;87m  ros2 launch offboard_demo offboard_demo.launch.py\n  ros2 launch custom_mode_demo custom_mode_demo.launch.py\n  ros2 launch aruco_tracker aruco_tracker.launch.py world_name:=aruco model_name:=x500_mono_cam_down_0\n  ros2 launch teleop teleop.launch.py\n  ros2 run   precision_land precision_land --ros-args -p use_sim_time:=true\n  ros2 launch precision_land_executor precision_land_executor.launch.py\033[0m\n'

# Scratch window: title it so the pane-border-format does not render the
# default (container hostname); the welcome banner is the first thing
# attendees see when they switch to this window with Ctrl-b 1.
tmux new-window -t "${SESSION}" -n scratch
SCRATCH_PANE="$(tmux display-message -p -t "${SESSION}:scratch" '#{pane_id}')"
tmux select-pane -t "${SCRATCH_PANE}" -T "scratch"
tmux send-keys -t "${SCRATCH_PANE}" "clear; workshop-welcome 2>/dev/null || true" Enter

# Focus the first pane and attach.
tmux select-window -t "${SESSION}:sim"
tmux select-pane -t "${SESSION}:sim.0"
exec tmux attach -t "${SESSION}"
