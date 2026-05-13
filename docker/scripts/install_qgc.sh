#!/usr/bin/env bash
set -eo pipefail

QGC_VERSION=$1
TARGETARCH=$2
# Install location. Dockerfile leaves this as /home/${USER}; setup_local.sh
# overrides to $HOME for any local username.
QGC_INSTALL_DIR="${QGC_INSTALL_DIR:-/home/${USER}}"

if [ "${TARGETARCH}" = "amd64" ]; then
    cd "${QGC_INSTALL_DIR}"
    [ -f QGroundControl-x86_64.AppImage ] || \
        wget https://github.com/mavlink/qgroundcontrol/releases/download/${QGC_VERSION}/QGroundControl-x86_64.AppImage
    chmod +x ./QGroundControl-x86_64.AppImage
    [ -d squashfs-root ] || ./QGroundControl-x86_64.AppImage --appimage-extract
    [ -d "${QGC_INSTALL_DIR}/QGroundControl" ] || mv "${QGC_INSTALL_DIR}/squashfs-root" "${QGC_INSTALL_DIR}/QGroundControl"
    chmod +x "${QGC_INSTALL_DIR}/QGroundControl/AppRun"
    [ -L "${QGC_INSTALL_DIR}/QGroundControl/qgroundcontrol" ] || \
        ln -s "${QGC_INSTALL_DIR}/QGroundControl/AppRun" "${QGC_INSTALL_DIR}/QGroundControl/qgroundcontrol"
else
    mkdir -p "${QGC_INSTALL_DIR}/QGroundControl"
    echo "QGroundControl is only available for amd64 architecture." >> "${QGC_INSTALL_DIR}/QGroundControl/install.log"
fi