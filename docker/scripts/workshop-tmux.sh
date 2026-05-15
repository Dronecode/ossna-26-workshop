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

# Mouse mode ON so attendees can click panes to focus them and scroll
# back through long-running command output with the wheel. To copy text
# while mouse mode is on, HOLD SHIFT while dragging — every common
# terminal (GNOME, Konsole, Alacritty, Kitty, iTerm2, Terminal.app)
# treats Shift+drag as a native terminal selection that bypasses tmux.
tmux set -g mouse on

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

# --- Easy-to-reach shortcuts (NO PREFIX needed) -----------------------------
# Some terminals (notably VSCode's built-in one) eat tmux's mouse events or
# block Ctrl-b. Bind a few common navigations to bare Alt-something so they
# work everywhere.
tmux bind -n M-1     select-window -t 0           # Alt+1 -> sim window
tmux bind -n M-2     select-window -t 1           # Alt+2 -> scratch window
tmux bind -n M-Left  previous-window              # Alt+Left -> prev window
tmux bind -n M-Right next-window                  # Alt+Right -> next window
tmux bind -n M-h     select-pane -L               # Alt+h/j/k/l -> move pane
tmux bind -n M-j     select-pane -D
tmux bind -n M-k     select-pane -U
tmux bind -n M-l     select-pane -R
tmux bind -n M-z     resize-pane -Z               # Alt+z toggles pane zoom

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

# Seed each pane with one short, quote-free command: `clear; workshop-hint
# TOPIC`. Earlier attempts at sending a long `printf '...long escape string'`
# via send-keys raced with the freshly-spawned shell and could leave the
# first pane stuck in an unterminated command line. A single tiny invocation
# of an external helper script avoids that entire class of bug.
tmux send-keys -t "${GZ_PANE}"      "clear; workshop-hint gazebo"  Enter
tmux send-keys -t "${PX4_PANE}"     "clear; workshop-hint px4"     Enter
tmux send-keys -t "${QGC_PANE}"     "clear; workshop-hint qgc"     Enter
tmux send-keys -t "${COMMON_PANE}"  "clear; workshop-hint common"  Enter
tmux send-keys -t "${EXAMPLE_PANE}" "clear; workshop-hint example" Enter

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
