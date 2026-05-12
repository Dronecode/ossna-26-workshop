SCRIPT=$(realpath "$0")
SCRIPTPATH=$(dirname "$SCRIPT")

# Parse command line arguments
NO_GUI=false
NVIDIA=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --no-gui)
            NO_GUI=true
            shift
            ;;
        --nvidia)
            NVIDIA=true
            shift
            ;;
        *)
            echo "Unknown argument: $1"
            echo "Usage: $0 [--no-gui] [--nvidia]"
            exit 1
            ;;
    esac
done

# Build docker run command
DOCKER_CMD="docker run -it --rm"

# Add GUI support unless --no-gui is specified
if [ "$NO_GUI" = false ]; then
    DOCKER_CMD="$DOCKER_CMD -v /tmp/.X11-unix:/tmp/.X11-unix:ro"
    DOCKER_CMD="$DOCKER_CMD -e DISPLAY=$DISPLAY"

    # Always forward /dev/dri so Mesa has a working DRM path. The nvidia
    # runtime by itself only provides NVIDIA's GL stack; it does not expose
    # the integrated GPU. Without /dev/dri the iris/i915 Mesa driver fails
    # to query DRM and Gazebo's renderer cannot create a GLX/EGL screen.
    DOCKER_CMD="$DOCKER_CMD --device /dev/dri:/dev/dri"
    # /dev/dri/* on the host is mode 660, owned by host groups (typically
    # 'video' for card* and 'render' for renderD*). The container's
    # 'ubuntu' user is not in those groups by default, so EGL/Vulkan/DRI
    # would fall back with "Permission denied". Pass the host GIDs so the
    # container user can open the GPU device nodes.
    DRI_GIDS=$(stat -c %g /dev/dri/card* /dev/dri/renderD* 2>/dev/null | sort -u)
    for gid in $DRI_GIDS; do
        DOCKER_CMD="$DOCKER_CMD --group-add $gid"
    done

    # Add nvidia runtime if --nvidia is specified
    if [ "$NVIDIA" = true ]; then
        # Check the nvidia runtime is actually registered with the Docker
        # daemon. Without nvidia-container-toolkit installed and configured,
        # `--runtime nvidia` fails with the unhelpful
        #     "unknown or invalid runtime name: nvidia"
        if ! docker info --format '{{json .Runtimes}}' 2>/dev/null | grep -q '"nvidia"'; then
            echo "Error: --nvidia requested but the 'nvidia' Docker runtime is not registered." >&2
            echo "" >&2
            echo "Install the NVIDIA Container Toolkit on the host:" >&2
            echo "  https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html" >&2
            echo "" >&2
            echo "After installing, run:" >&2
            echo "  sudo nvidia-ctk runtime configure --runtime=docker" >&2
            echo "  sudo systemctl restart docker" >&2
            echo "" >&2
            echo "Or, if you don't need the NVIDIA GPU, omit --nvidia and the script" >&2
            echo "will fall back to the integrated GPU via /dev/dri." >&2
            exit 1
        fi
        DOCKER_CMD="$DOCKER_CMD --runtime nvidia"
        DOCKER_CMD="$DOCKER_CMD -e NVIDIA_VISIBLE_DEVICES=all"
        DOCKER_CMD="$DOCKER_CMD -e NVIDIA_DRIVER_CAPABILITIES=all"
        # Route GLX through NVIDIA's vendor library so Gazebo's Ogre
        # renderer actually uses the discrete GPU instead of trying the
        # Mesa iris driver first (which causes "failed to create dri3
        # screen" / "failed to load driver: iris" warnings on hybrid
        # laptops where both the integrated GPU and the dGPU are visible).
        DOCKER_CMD="$DOCKER_CMD -e __NV_PRIME_RENDER_OFFLOAD=1"
        DOCKER_CMD="$DOCKER_CMD -e __GLX_VENDOR_LIBRARY_NAME=nvidia"
    fi
fi

# Add common options
DOCKER_CMD="$DOCKER_CMD -p 18570:18570/udp"
DOCKER_CMD="$DOCKER_CMD -p 8765:8765"
DOCKER_CMD="$DOCKER_CMD -v ${SCRIPTPATH}/..:/home/ubuntu/ossna-26-workshop_ws/src/ossna-26-workshop"
DOCKER_CMD="$DOCKER_CMD --name=px4-ossna-26"
DOCKER_CMD="$DOCKER_CMD -w /home/ubuntu/ossna-26-workshop_ws"
DOCKER_CMD="$DOCKER_CMD dronecode/ossna-26-workshop bash"

# Execute the command
eval $DOCKER_CMD
