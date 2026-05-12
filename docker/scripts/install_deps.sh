#!/usr/bin/env bash
set -euo pipefail

# SUDO is empty inside the Dockerfile (running as root); setup_local.sh sets
# it to "sudo" so the same script works for a non-root local install.
SUDO="${SUDO:-}"

${SUDO} apt-get update && \
${SUDO} apt-get upgrade -y && \
${SUDO} apt-get install -y --no-install-recommends \
    curl \
    lsb-release \
    gnupg && \
${SUDO} sh -c 'curl https://packages.osrfoundation.org/gazebo.gpg --output /usr/share/keyrings/pkgs-osrf-archive-keyring.gpg' && \
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/pkgs-osrf-archive-keyring.gpg] http://packages.osrfoundation.org/gazebo/ubuntu-stable $(lsb_release -cs) main" | ${SUDO} tee /etc/apt/sources.list.d/gazebo-stable.list > /dev/null && \
${SUDO} apt-get update && \
${SUDO} apt-get install -y --no-install-recommends \
    gz-harmonic \
    ros-humble-foxglove-bridge \
    bc \
    dmidecode \
    libboost-all-dev \
    gstreamer1.0-plugins-bad \
    gstreamer1.0-plugins-base \
    gstreamer1.0-plugins-good \
    gstreamer1.0-plugins-ugly \
    gstreamer1.0-libav \
    libeigen3-dev \
    libgstreamer-plugins-base1.0-dev \
    libimage-exiftool-perl \
    libxml2-utils \
    pkg-config \
    protobuf-compiler \
    wget \
	libxcb-xinerama0 \
	libxkbcommon-x11-0 \
	libxcb-cursor-dev \
    ros-humble-actuator-msgs \
    ros-humble-gps-msgs \
    ros-humble-vision-msgs \
    libgflags-dev \
    python3-rospkg 

${SUDO} rm -rf /var/lib/apt/lists/*
${SUDO} apt-get clean