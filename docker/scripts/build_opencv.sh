#!/usr/bin/env bash
set -eo pipefail

OPENCV_VERSION=$1
# Build directory defaults to /OpenCV (Dockerfile) but can be overridden when
# running locally via setup_local.sh.
OPENCV_BUILD_DIR="${OPENCV_BUILD_DIR:-/OpenCV}"

CMAKE_FLAGS=" \
   -DCPACK_BINARY_DEB=ON \
   -DBUILD_EXAMPLES=OFF \
   -DBUILD_opencv_python2=OFF \
   -DBUILD_opencv_python3=ON \
   -DBUILD_opencv_java=OFF \
   -DCMAKE_BUILD_TYPE=RELEASE \
   -DCMAKE_INSTALL_PREFIX=/usr/local \
   -DOPENCV_EXTRA_MODULES_PATH=${OPENCV_BUILD_DIR}/opencv_contrib/modules \
   -DCUDA_FAST_MATH=ON \
   -DEIGEN_INCLUDE_PATH=/usr/include/eigen3 \
   -DWITH_EIGEN=ON \
   -DOPENCV_ENABLE_NONFREE=OFF \
   -DOPENCV_GENERATE_PKGCONFIG=ON \
   -DBUILD_PERF_TESTS=OFF \
   -DBUILD_TESTS=OFF"

# Use nproc on Linux, sysctl on macOS
JOBS=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)

mkdir -p "${OPENCV_BUILD_DIR}" && cd "${OPENCV_BUILD_DIR}" &&

[ -d opencv ]         || git clone --depth 1 --branch ${OPENCV_VERSION} https://github.com/opencv/opencv.git
[ -d opencv_contrib ] || git clone --depth 1 --branch ${OPENCV_VERSION} https://github.com/opencv/opencv_contrib.git

cmake -S opencv -B build ${CMAKE_FLAGS} && \
cmake --build build --config Release -- -j${JOBS} && \
cmake --install build --config Release --prefix ./install