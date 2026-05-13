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
tmux set -g mouse on
tmux set -g history-limit 20000
tmux setw -g mode-keys vi
tmux set -g status-interval 1            # refresh status bar (and animations) every second

# --- Colors: a punchy "OSSNA 26" palette on a dark background ---
# tmux 3.2+ honours hex colours; the image ships tmux 3.2a.
tmux set -g status-style              "bg=#1a1a2e,fg=#e0e0e0"
tmux set -g message-style             "bg=#ffdd55,fg=#1a1a2e,bold"
tmux set -g pane-border-style         "fg=#444466"               # dim purple-gray
tmux set -g pane-active-border-style  "fg=#55ddff,bold"          # bright cyan for the active pane

# Pane title in the border: pink dot + bold white name (visible against #1a1a2e)
tmux set -g pane-border-format "  #[fg=#ff55dd,bold]●#[default] #[fg=#ffffff,bold]#{pane_title}#[default]  "

# Window list in the status bar
tmux setw -g window-status-style           "fg=#999999"
tmux setw -g window-status-current-style   "fg=#ffdd55,bold,bg=#440044"
tmux setw -g window-status-format          " #I:#W "
tmux setw -g window-status-current-format  " #I:#W "

# Flash the window name yellow when an inactive window has new output
tmux set -g monitor-activity on
tmux set -g visual-activity off
tmux setw -g window-status-activity-style  "fg=#ffdd55,bold,blink"

# --- Animations ---
# status-left: rainbow "OSSNA 2026" with a single highlighted letter that
# rotates every second (workshop-banner generates the tmux format string).
# status-right: a braille spinner that advances every second, plus a clock.
tmux set -g status-left-length 40
tmux set -g status-right-length 80
tmux set -g status-left  "#(workshop-banner) "
tmux set -g status-right "#[fg=#55ddff,bold]#(workshop-spinner)#[default] #[fg=#999999]workshop #[fg=#bb55ff,bold]%H:%M:%S "

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

# Seed each pane with hint comments. The shell sees these as no-op
# comments, they just remind the attendee what to paste where.
tmux send-keys -t "${GZ_PANE}" \
    "# === Gazebo ===" Enter \
    "# Paste, then Enter:" Enter \
    "#   python3 /home/ubuntu/PX4-gazebo-models/simulation-gazebo \\" Enter \
    "#     --model_store /home/ubuntu/PX4-gazebo-models/ --world default" Enter

tmux send-keys -t "${PX4_PANE}" \
    "# === PX4 SITL ===" Enter \
    "# Wait until Gazebo is up, then paste:" Enter \
    "#   PX4_GZ_STANDALONE=1 PX4_SYS_AUTOSTART=4001 \\" Enter \
    "#     PX4_PARAM_UXRCE_DDS_SYNCT=0 \\" Enter \
    "#     /home/ubuntu/px4_sitl/bin/px4 -w /home/ubuntu/px4_sitl/romfs" Enter

tmux send-keys -t "${QGC_PANE}" \
    "# === QGroundControl ===" Enter \
    "# Needs an X11-enabled container (default for ./docker/docker_run.sh)." Enter \
    "#   /home/ubuntu/QGroundControl/qgroundcontrol" Enter

tmux send-keys -t "${COMMON_PANE}" \
    "# === common.launch.py ===" Enter \
    "# XRCE-DDS agent, clock + foxglove bridges, robot_state_publisher, px4_tf, static TF:" Enter \
    "#   ros2 launch px4_ossna_26 common.launch.py" Enter

tmux send-keys -t "${EXAMPLE_PANE}" \
    "# === example launch ===" Enter \
    "# Pick ONE of these once common.launch.py is up:" Enter \
    "#   ros2 launch offboard_demo offboard_demo.launch.py" Enter \
    "#   ros2 launch custom_mode_demo custom_mode_demo.launch.py" Enter \
    "#   ros2 launch aruco_tracker aruco_tracker.launch.py world_name:=aruco model_name:=x500_mono_cam_down_0" Enter \
    "#   ros2 launch teleop teleop.launch.py" Enter \
    "#   ros2 run   precision_land precision_land --ros-args -p use_sim_time:=true" Enter \
    "#   ros2 launch precision_land_executor precision_land_executor.launch.py" Enter

# Scratch window for inspection commands.
tmux new-window -t "${SESSION}" -n scratch
tmux send-keys -t "${SESSION}:scratch" \
    "# === scratch ===" Enter \
    "# ros2 node list   ros2 topic list   ros2 topic echo /fmu/out/vehicle_status_v1" Enter

# Focus the first pane and attach.
tmux select-window -t "${SESSION}:sim"
tmux select-pane -t "${SESSION}:sim.0"
exec tmux attach -t "${SESSION}"
