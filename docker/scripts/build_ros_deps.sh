#!/usr/bin/env bash
set -eo pipefail

MICRO_XRCE_DDS_AGENT_VERSION=$1
PX4_MSGS_VERSION=$2
PX4_ROS2_INTERFACE_LIB_VERSION=$3
PX4_ROS_COM_VERSION=$4
# Workspace path defaults to /root/px4_ros_ws (Dockerfile) but can be overridden
# when running locally via setup_local.sh.
PX4_ROS_WS="${PX4_ROS_WS:-/root/px4_ros_ws}"

mkdir -p "${PX4_ROS_WS}/src" && cd "${PX4_ROS_WS}/src" && \
[ -d Micro-XRCE-DDS-Agent ]    || git clone --depth 1 -b ${MICRO_XRCE_DDS_AGENT_VERSION} https://github.com/eProsima/Micro-XRCE-DDS-Agent.git
[ -d px4_msgs ]                || git clone --depth 1 -b ${PX4_MSGS_VERSION} https://github.com/PX4/px4_msgs.git
[ -d px4-ros2-interface-lib ]  || git clone --depth 1 -b ${PX4_ROS2_INTERFACE_LIB_VERSION} https://github.com/Auterion/px4-ros2-interface-lib.git
[ -d px4_ros_com ]             || git clone --depth 1 -b ${PX4_ROS_COM_VERSION} https://github.com/PX4/px4_ros_com.git
[ -d vision_opencv ]           || git clone --depth 1 -b humble https://github.com/ros-perception/vision_opencv.git
[ -d image_common ]            || git clone --depth 1 -b humble https://github.com/ros-perception/image_common.git
[ -d image_transport_plugins ] || git clone --depth 1 -b humble https://github.com/ros-perception/image_transport_plugins.git
[ -d ros_gz ]                  || git clone --depth 1 -b humble https://github.com/gazebosim/ros_gz.git
rm -rf ros_gz/ros_ign* \
    ros_gz/ros_gz_sim_demos \
    image_transport_plugins/compressed_depth_image_transport \
    image_transport_plugins/theora_image_transport \
    image_transport_plugins/zstd_image_transport \
    image_transport_plugins/image_transport_plugins
cd .. && source /opt/ros/humble/setup.bash
GZ_VERSION=harmonic colcon build