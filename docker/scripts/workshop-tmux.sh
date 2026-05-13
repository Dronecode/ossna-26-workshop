#!/usr/bin/env bash
# workshop-tmux: launch a preconfigured tmux layout for the OSSNA 2026
# PX4 + ROS 2 workshop.
#
# Creates one named session ('ossna') with two windows:
#
#   sim     - 2x2 grid of panes labelled 'gazebo', 'px4', 'qgc', 'ros2'.
#             Each pane gets a comment-only hint showing the command you
#             would paste there. The script does not start anything for
#             you — you still copy-paste the actual commands from the
#             workshop docs, but now into ONE terminal window.
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

# Friendlier defaults: per-pane titles in the border, mouse on,
# bigger scrollback, vi-style copy mode.
tmux set -g pane-border-status top
tmux set -g pane-border-format "  #[bold]#{pane_index}: #{pane_title}#[default]  "
tmux set -g mouse on
tmux set -g history-limit 20000
tmux setw -g mode-keys vi
tmux set -g status-right "ossna-26-workshop | prefix=C-b | ?=help"

# Create 3 more panes (4 total), then ask tmux to arrange them as an even
# 2x2 grid. Using `tiled` avoids hand-managing pane indices through a
# sequence of horizontal/vertical splits.
tmux split-window -t "${SESSION}:sim"
tmux split-window -t "${SESSION}:sim"
tmux split-window -t "${SESSION}:sim"
tmux select-layout -t "${SESSION}:sim" tiled

# Title each pane by index. With `tiled` on 4 panes the layout is:
#   0 = top-left  1 = top-right
#   2 = bottom-left  3 = bottom-right
tmux select-pane -t "${SESSION}:sim.0" -T "gazebo"
tmux select-pane -t "${SESSION}:sim.1" -T "px4"
tmux select-pane -t "${SESSION}:sim.2" -T "ros2 (common.launch.py + example launches)"
tmux select-pane -t "${SESSION}:sim.3" -T "qgc"

# Seed each pane with hint comments. The shell sees these as no-op comments,
# they just remind the attendee what to paste where.
tmux send-keys -t "${SESSION}:sim.0" \
    "# === pane 0: Gazebo ===" Enter \
    "# Paste, then Enter:" Enter \
    "#   python3 /home/ubuntu/PX4-gazebo-models/simulation-gazebo \\" Enter \
    "#     --model_store /home/ubuntu/PX4-gazebo-models/ --world default" Enter

tmux send-keys -t "${SESSION}:sim.1" \
    "# === pane 1: PX4 SITL ===" Enter \
    "# Wait until Gazebo is up, then paste:" Enter \
    "#   PX4_GZ_STANDALONE=1 PX4_SYS_AUTOSTART=4001 \\" Enter \
    "#     PX4_PARAM_UXRCE_DDS_SYNCT=0 \\" Enter \
    "#     /home/ubuntu/px4_sitl/bin/px4 -w /home/ubuntu/px4_sitl/romfs" Enter

tmux send-keys -t "${SESSION}:sim.2" \
    "# === pane 2: ROS 2 ===" Enter \
    "# First the workshop's common launch (XRCE-DDS agent, clock+foxglove bridges):" Enter \
    "#   ros2 launch px4_ossna_26 common.launch.py" Enter \
    "# Then in the SAME pane (split with Ctrl+b \" if you want to keep both running):" Enter \
    "#   ros2 launch offboard_demo offboard_demo.launch.py" Enter \
    "#   ros2 launch aruco_tracker aruco_tracker.launch.py world_name:=aruco model_name:=x500_mono_cam_down_0" Enter \
    "#   ros2 launch custom_mode_demo custom_mode_demo.launch.py" Enter \
    "#   ros2 launch teleop teleop.launch.py" Enter \
    "#   ros2 run   precision_land precision_land --ros-args -p use_sim_time:=true" Enter \
    "#   ros2 launch precision_land_executor precision_land_executor.launch.py" Enter

tmux send-keys -t "${SESSION}:sim.3" \
    "# === pane 3: QGroundControl ===" Enter \
    "# Needs an X11-enabled container (default for ./docker/docker_run.sh)." Enter \
    "#   /home/ubuntu/QGroundControl/qgroundcontrol" Enter

# Scratch window for inspection commands.
tmux new-window -t "${SESSION}" -n scratch
tmux send-keys -t "${SESSION}:scratch" \
    "# === scratch ===" Enter \
    "# ros2 node list   ros2 topic list   ros2 topic echo /fmu/out/vehicle_status_v1" Enter

# Focus the first pane and attach.
tmux select-window -t "${SESSION}:sim"
tmux select-pane -t "${SESSION}:sim.0"
exec tmux attach -t "${SESSION}"
