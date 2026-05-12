#!/usr/bin/env bash
# setup_local.sh
#
# Reproduce the workshop docker image stages on the host. Use this if Docker
# is not an option (e.g. macOS without Docker Desktop, GPU driver issues
# inside the container, restricted environments) and you want to run the
# workshop natively.
#
# What it does — mirrors docker/Dockerfile:
#   1. install system packages (Gazebo Harmonic, ROS 2 Humble, build deps)
#   2. build OpenCV 4.10 from source (aruco_tracker depends on it)
#   3. clone + build ROS 2 deps (Micro-XRCE-DDS-Agent, px4_msgs,
#      px4-ros2-interface-lib, px4_ros_com, vision_opencv, image_common,
#      image_transport_plugins, ros_gz)
#   4. clone + build PX4 v1.16 SITL
#   5. install QGroundControl v5.0.8
#   6. build the workshop workspace
#
# Supported:
#   Ubuntu 22.04 (matches the docker base image, recommended)
#   Ubuntu 24.04 (mostly OK; some apt package names may differ)
#   macOS:        ROS 2 Humble + Gazebo Harmonic are NOT officially supported
#                 on macOS. The script refuses by default and points you to
#                 Docker via OrbStack / Colima / Lima.
#
# Time:  ~45-60 min on a fast SSD with good network
# Space: ~20 GB

set -eo pipefail

# ---------- defaults (matched against the Dockerfile) ----------
OPENCV_VERSION="4.10.0"
MICRO_XRCE_DDS_AGENT_VERSION="v2.4.2"
PX4_MSGS_VERSION="release/1.16"
PX4_ROS2_INTERFACE_LIB_VERSION="release/1.16"
PX4_ROS_COM_VERSION="release/1.16"
PX4_VERSION="v1.16.0"
QGC_VERSION="v5.0.8"

# ---------- arg parsing ----------
SKIP_DEPS=false
SKIP_OPENCV=false
SKIP_ROS_DEPS=false
SKIP_PX4=false
SKIP_QGC=false
SKIP_WS=false
PREFIX=""

usage() {
    cat <<EOF
Usage: $0 [options]

Mirrors docker/Dockerfile stages on the host machine.

Options:
  --prefix DIR        Root directory under which to clone/build artifacts.
                      Default: \$HOME (matches the Dockerfile layout, with
                      PX4-Autopilot/, px4_ros_ws/, px4_sitl/, QGroundControl/,
                      and ossna-26-workshop_ws/ directly under \$HOME).
  --skip-deps         Skip apt install (deps already present)
  --skip-opencv       Skip OpenCV 4.10 build
  --skip-ros-deps     Skip ROS 2 deps clone + colcon build
  --skip-px4          Skip PX4 SITL clone + build
  --skip-qgc          Skip QGroundControl install
  --skip-ws           Skip building the workshop workspace
  -h | --help         This help

Run from the repo root: ./setup_local.sh
EOF
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --prefix)        PREFIX="$2"; shift 2 ;;
        --skip-deps)     SKIP_DEPS=true;     shift ;;
        --skip-opencv)   SKIP_OPENCV=true;   shift ;;
        --skip-ros-deps) SKIP_ROS_DEPS=true; shift ;;
        --skip-px4)      SKIP_PX4=true;      shift ;;
        --skip-qgc)      SKIP_QGC=true;      shift ;;
        --skip-ws)       SKIP_WS=true;       shift ;;
        -h|--help)       usage; exit 0 ;;
        *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
    esac
done

# ---------- locate this script + repo root ----------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${SCRIPT_DIR}"
DOCKER_SCRIPTS="${REPO_ROOT}/docker/scripts"

if [ ! -d "${DOCKER_SCRIPTS}" ]; then
    echo "Error: cannot find ${DOCKER_SCRIPTS}. Run this from the repo root." >&2
    exit 1
fi

# ---------- OS detection ----------
case "$(uname -s)" in
    Linux*)
        if ! command -v lsb_release >/dev/null 2>&1; then
            sudo apt-get update -qq && sudo apt-get install -y -qq lsb-release
        fi
        UBUNTU_CODENAME="$(lsb_release -cs)"
        UBUNTU_VERSION="$(lsb_release -rs)"
        if [ "$(lsb_release -is)" != "Ubuntu" ]; then
            echo "Error: only Ubuntu is supported on Linux. Got: $(lsb_release -is)" >&2
            exit 1
        fi
        case "${UBUNTU_VERSION}" in
            22.04|24.04) ;;
            *) echo "Warning: only Ubuntu 22.04 (recommended) and 24.04 are tested. You have ${UBUNTU_VERSION}." >&2 ;;
        esac
        OS=ubuntu
        SUDO=sudo
        ARCH="$(dpkg --print-architecture)"
        ;;
    Darwin*)
        cat >&2 <<'EOF'
macOS is not a supported target for native install. ROS 2 Humble and Gazebo
Harmonic do not have first-class macOS support, and the workshop assumes the
Ubuntu 22.04 software stack throughout. Trying to reproduce it natively will
likely fail at colcon build of the ROS 2 deps.

The supported macOS path is Docker (the same image the rest of the workshop
uses). Install one of:

  brew install orbstack           # easiest; native virt, X11 fwd
  brew install colima             # lightweight CLI alternative
  brew install --cask docker      # Docker Desktop

then run:

  ./docker/docker_build.sh
  ./docker/docker_run.sh

If you absolutely must try native macOS install anyway, pass --force-macos.
EOF
        if [[ "${OSSNA_FORCE_MACOS:-}" != "1" ]]; then
            exit 1
        fi
        OS=macos
        SUDO=""
        ARCH="amd64" # QGC AppImage isn't usable on macOS; install_qgc will write a stub
        ;;
    *)
        echo "Error: unsupported OS $(uname -s)" >&2
        exit 1
        ;;
esac

# ---------- prefix paths ----------
[ -n "${PREFIX}" ] || PREFIX="${HOME}"
mkdir -p "${PREFIX}"

# Match Dockerfile layout: $HOME/PX4-Autopilot, $HOME/px4_ros_ws, $HOME/px4_sitl,
# $HOME/QGroundControl, $HOME/PX4-gazebo-models, $HOME/ossna-26-workshop_ws.
export OPENCV_BUILD_DIR="${PREFIX}/OpenCV"
export PX4_ROS_WS="${PREFIX}/px4_ros_ws"
export PX4_BUILD_DIR="${PREFIX}"          # PX4-Autopilot is cloned into this dir
export QGC_INSTALL_DIR="${PREFIX}"        # QGroundControl/ is created under this dir

WS_DIR="${PREFIX}/ossna-26-workshop_ws"

echo "==> Install prefix:   ${PREFIX}"
echo "==> OS:               ${OS} ${UBUNTU_VERSION:-} ${ARCH}"
echo "==> Workshop ws:      ${WS_DIR}"
echo ""

# ---------- 1. apt deps + ROS 2 Humble base ----------
if ! ${SKIP_DEPS} && [ "${OS}" = "ubuntu" ]; then
    echo "==> [1/6] Installing system packages..."

    # ROS 2 Humble apt repo (the docker image starts FROM ros:humble-ros-base,
    # which already has this set up; locally we need to add it ourselves).
    if [ ! -f /etc/apt/sources.list.d/ros2.list ] && [ ! -f /etc/apt/sources.list.d/ros2.sources ]; then
        ${SUDO} apt-get update -qq
        ${SUDO} apt-get install -y -qq curl gnupg lsb-release software-properties-common
        ${SUDO} add-apt-repository -y universe
        ${SUDO} curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key \
            -o /usr/share/keyrings/ros-archive-keyring.gpg
        echo "deb [arch=${ARCH} signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu ${UBUNTU_CODENAME} main" \
            | ${SUDO} tee /etc/apt/sources.list.d/ros2.list > /dev/null
    fi

    ${SUDO} apt-get update
    ${SUDO} apt-get install -y --no-install-recommends \
        ros-humble-ros-base \
        ros-dev-tools \
        python3-colcon-common-extensions \
        python3-rosdep \
        python3-vcstool \
        git

    if [ ! -f /etc/ros/rosdep/sources.list.d/20-default.list ]; then
        ${SUDO} rosdep init || true
    fi
    rosdep update || true

    # Now run the same apt-install pass the Dockerfile does (Gazebo Harmonic
    # repo + workshop deps). install_deps.sh is sudo-aware.
    SUDO="${SUDO}" "${DOCKER_SCRIPTS}/install_deps.sh"
elif ! ${SKIP_DEPS}; then
    echo "==> [1/6] (deps step is Ubuntu-only)"
fi

# Source ROS 2 for the rest of the script
if [ -f /opt/ros/humble/setup.bash ]; then
    # ROS setup.bash references unbound vars; relax nounset around it
    set +u
    source /opt/ros/humble/setup.bash
    set -u
else
    echo "Error: /opt/ros/humble/setup.bash not found after deps install" >&2
    exit 1
fi

# ---------- 2. OpenCV 4.10 ----------
if ! ${SKIP_OPENCV}; then
    echo "==> [2/6] Building OpenCV ${OPENCV_VERSION} (~10-15 min)..."
    OPENCV_BUILD_DIR="${OPENCV_BUILD_DIR}" \
        "${DOCKER_SCRIPTS}/build_opencv.sh" "${OPENCV_VERSION}"

    # Mirror Dockerfile pre-dev stage: install OpenCV into /usr/local and run ldconfig
    if [ "${OS}" = "ubuntu" ] && [ -d "${OPENCV_BUILD_DIR}/install" ]; then
        ${SUDO} cp -r "${OPENCV_BUILD_DIR}/install/"* /usr/local/
        echo "/usr/local/lib" | ${SUDO} tee /etc/ld.so.conf.d/opencv.conf >/dev/null
        ${SUDO} ldconfig
    fi
fi

# ---------- 3. ROS 2 deps ----------
if ! ${SKIP_ROS_DEPS}; then
    echo "==> [3/6] Building ROS 2 dependencies into ${PX4_ROS_WS} (~10-15 min)..."
    PX4_ROS_WS="${PX4_ROS_WS}" \
        "${DOCKER_SCRIPTS}/build_ros_deps.sh" \
        "${MICRO_XRCE_DDS_AGENT_VERSION}" \
        "${PX4_MSGS_VERSION}" \
        "${PX4_ROS2_INTERFACE_LIB_VERSION}" \
        "${PX4_ROS_COM_VERSION}"
fi

# ---------- 4. PX4 v1.16 SITL ----------
if ! ${SKIP_PX4}; then
    echo "==> [4/6] Building PX4 ${PX4_VERSION} SITL into ${PX4_BUILD_DIR}/PX4-Autopilot (~10-15 min)..."
    USER="${USER}" PX4_BUILD_DIR="${PX4_BUILD_DIR}" \
        "${DOCKER_SCRIPTS}/build_px4.sh" "${PX4_VERSION}"

    # The Dockerfile also copies the PX4 Gazebo models into ~/PX4-gazebo-models.
    # Replicate that so the workshop docs commands work verbatim.
    if [ ! -d "${PREFIX}/PX4-gazebo-models" ]; then
        cp -r "${PX4_BUILD_DIR}/PX4-Autopilot/Tools/simulation/gz" "${PREFIX}/PX4-gazebo-models"
    fi
fi

# ---------- 5. QGroundControl ----------
if ! ${SKIP_QGC} && [ "${OS}" = "ubuntu" ]; then
    echo "==> [5/6] Installing QGroundControl ${QGC_VERSION}..."
    QGC_INSTALL_DIR="${QGC_INSTALL_DIR}" \
        "${DOCKER_SCRIPTS}/install_qgc.sh" "${QGC_VERSION}" "${ARCH}"
fi

# ---------- 6. Workshop workspace ----------
if ! ${SKIP_WS}; then
    echo "==> [6/6] Building the workshop workspace into ${WS_DIR}..."
    mkdir -p "${WS_DIR}/src"
    # Link this repo into the workspace src/ instead of copying it
    if [ ! -e "${WS_DIR}/src/ossna-26-workshop" ]; then
        ln -s "${REPO_ROOT}" "${WS_DIR}/src/ossna-26-workshop"
    fi
    set +u
    source "${PX4_ROS_WS}/install/setup.bash"
    set -u
    ( cd "${WS_DIR}" && colcon build --symlink-install --cmake-args -DCMAKE_BUILD_TYPE=RelWithDebInfo )
fi

cat <<EOF

================================================================================
 Setup complete.

 To use the workshop, in a new shell:

   source /opt/ros/humble/setup.bash
   source ${PX4_ROS_WS}/install/setup.bash
   source ${WS_DIR}/install/setup.bash

 Then run any of the workshop launchfiles, e.g.

   ros2 launch px4_ossna_26 common.launch.py

 PX4 SITL binary:        ${PX4_BUILD_DIR}/px4_sitl/bin/px4
 PX4 Gazebo models:      ${PREFIX}/PX4-gazebo-models
 QGroundControl:         ${QGC_INSTALL_DIR}/QGroundControl/qgroundcontrol
 Workshop ws:            ${WS_DIR}
================================================================================
EOF
