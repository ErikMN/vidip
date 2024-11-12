#!/usr/bin/env sh
#
# Make Axis camera an IP camera, dependencies:
# sudo apt install v4l-utils v4l2loopback-dkms gstreamer1.0-tools
# sudo dnf install v4l-utils akmod-v4l2loopback gstreamer1-plugins-base
#
# Test it here: https://webcamtests.com/
#
set -eu

VERSION="1.0.0"

DEFAULT_VIDEO_NUMBER=0
VIDEO_NUMBER=${DEFAULT_VIDEO_NUMBER}
VIDEO_DEVICE="/dev/video${DEFAULT_VIDEO_NUMBER}"
MODULE_NAME="v4l2loopback"
RESOLUTION="1280x720"
CAMERA_USER="${CAMERA_USER:-root}"
CAMERA_PASS="${CAMERA_PASS:-pass}"
DEFAULT_IP_PREFIX="192.168.0."

# Print colors:
FMT_GREEN=$(printf '\033[32m')
FMT_YELLOW=$(printf '\033[33m')
FMT_RED=$(printf '\033[31m')
FMT_BLUE=$(printf '\033[34m')
FMT_RESET=$(printf '\033[0m')

# Check if v4l2loopback module is loaded and try to identify the video device number:
find_existing_video_device() {
  if is_module_loaded; then
    # Iterate over each video device:
    for dev in /dev/video*; do
      # Check if the device is labeled "Video-Loopback":
      if v4l2-ctl -d "$dev" --all 2>/dev/null | grep -q "Video-Loopback"; then
        VIDEO_DEVICE="$dev"
        VIDEO_NUMBER="${dev#/dev/video}"
        echo "${FMT_GREEN}Found existing v4l2loopback device: ${VIDEO_DEVICE}${FMT_RESET}"
        return 0
      fi
    done
  fi
  echo "${FMT_YELLOW}No existing v4l2loopback device found. Using: ${VIDEO_DEVICE}.${FMT_RESET}"
}

is_module_loaded() {
  lsmod | grep -q "$MODULE_NAME"
}

# Function to load v4l2loopback module:
load_module() {
  if is_module_loaded; then
    # The module is already loaded, display info:
    check_module
    return 0
  fi

  # Call find_existing_video_device to set VIDEO_DEVICE and VIDEO_NUMBER before loading:
  find_existing_video_device

  echo "Loading $MODULE_NAME module..."
  modprobe "$MODULE_NAME" video_nr="$VIDEO_NUMBER" card_label=Video-Loopback-"$VIDEO_NUMBER" exclusive_caps=1

  if is_module_loaded; then
    echo "${FMT_GREEN}$MODULE_NAME module loaded successfully on $VIDEO_DEVICE${FMT_RESET}"
  else
    echo "${FMT_RED}Failed to load $MODULE_NAME module.${FMT_RESET}"
    exit 2
  fi
}

# Function to unload v4l2loopback module:
unload_module() {
  echo "Unloading $MODULE_NAME module..."
  modprobe -r "$MODULE_NAME"

  if ! is_module_loaded; then
    echo "${FMT_GREEN}$MODULE_NAME module unloaded successfully.${FMT_RESET}"
  else
    echo "${FMT_RED}Failed to unload $MODULE_NAME module.${FMT_RESET}"
    exit 3
  fi
}

# Function to check if v4l2loopback module is loaded:
check_module() {
  if is_module_loaded; then
    echo "${FMT_GREEN}$MODULE_NAME module is currently loaded.${FMT_RESET}"

    # Call find_existing_video_device to set VIDEO_DEVICE and VIDEO_NUMBER if loaded:
    find_existing_video_device

    # Check if v4l2-ctl is available and list the device information:
    v4l2-ctl --list-devices -d "$VIDEO_DEVICE"
    return 0
  else
    echo "${FMT_YELLOW}$MODULE_NAME module is not loaded.${FMT_RESET}"
    echo "Please load it by running this script with the -l or --load option:"
    echo "  sudo $(basename "$0") -l"
    return 1
  fi
}

# Usage function:
show_usage() {
  echo "Usage: $0 [options] <IP_ADDRESS or last 3 digits>"
  echo "Options:"
  echo "  -l, --load     Load the v4l2loopback module"
  echo "  -u, --unload   Unload the v4l2loopback module"
  echo "  -c, --check    Check if the v4l2loopback module is loaded"
  echo "  -h, --help     Show this help message"
  echo
  echo "Example:"
  echo "  $0 192.168.0.90"
  echo "  $0 90           # This would assume IP address 192.168.0.90"
}

# Check if the OS is Linux:
if [ "$(uname)" != "Linux" ]; then
  echo "This script only runs on Linux systems."
  exit 1
fi

# Check that arguments are provided:
if [ "$#" -eq 0 ]; then
  show_usage
  exit 1
fi

# Make sure that GStreamer tools is installed:
if ! command -v gst-launch-1.0 >/dev/null; then
  echo "${FMT_RED}Error: GStreamer tools is not installed.${FMT_RESET}"
  echo "  Debian/Ubuntu: 'sudo apt install gstreamer1.0-tools'"
  echo "  Fedora: 'sudo dnf install gstreamer1-plugins-base'"
  exit 1
fi

# Make sure that v4l-utils is installed:
if ! command -v v4l2-ctl >/dev/null; then
  echo "${FMT_RED}Error: v4l-utils is not installed.${FMT_RESET}"
  echo "  Debian/Ubuntu: 'sudo apt install v4l-utils v4l2loopback-dkms'"
  echo "  Fedora: 'sudo dnf install v4l-utils akmod-v4l2loopback'"
  exit 1
fi

# Check for flags:
case "$1" in
-l | --load)
  load_module
  exit 0
  ;;
-u | --unload)
  unload_module
  exit 0
  ;;
-c | --check)
  check_module
  exit 0
  ;;
-h | --help)
  show_usage
  exit 0
  ;;
-v | --version)
  echo $VERSION
  exit 0
  ;;
esac

# Validate the IP address or last 3 digits:
if echo "$1" | grep -Eq '^[0-9]{1,3}$'; then
  # Only the last three digits provided, append to default prefix:
  if [ "$1" -ge 0 ] && [ "$1" -le 255 ]; then
    CAMERA_IP="${DEFAULT_IP_PREFIX}$1"
  else
    echo "${FMT_RED}Error: The last three digits of the IP should be between 0 and 255.${FMT_RESET}"
    exit 1
  fi
elif echo "$1" | grep -Eq '^([0-9]{1,3}\.){3}[0-9]{1,3}$'; then
  # Full IP address provided:
  CAMERA_IP="$1"
else
  echo "${FMT_RED}Error: Invalid input '$1'. Please provide either the last 3 digits (0-255) or a full IP address.${FMT_RESET}"
  exit 1
fi

echo "${FMT_BLUE}Using IP address: $CAMERA_IP${FMT_RESET}"

# Check if v4l2loopback module is loaded:
check_module || exit 2

# Verify the device exists:
if [ ! -e "$VIDEO_DEVICE" ]; then
  echo "${FMT_RED}Device $VIDEO_DEVICE does not exist. Exiting.${FMT_RESET}"
  exit 3
fi

# Build the GStreamer pipeline with the provided IP address:
GSTREAMER_CMD="gst-launch-1.0 \
  rtspsrc latency=0 location=rtsp://${CAMERA_USER}:${CAMERA_PASS}@${CAMERA_IP}/axis-media/media.amp?resolution=${RESOLUTION} ! \
  rtph264depay ! \
  decodebin ! \
  videoconvert ! \
  v4l2sink device=${VIDEO_DEVICE}"

# Start streaming:
echo "${FMT_BLUE}Starting video stream from IP camera at $CAMERA_IP. Press Ctrl+C to stop.${FMT_RESET}"
sh -c "$GSTREAMER_CMD" || {
  echo
  echo "${FMT_RED}Error: Failed to start video stream from IP camera at $CAMERA_IP.${FMT_RESET}"
  echo "Please check the following:"
  echo " - The IP address ($CAMERA_IP) is correct and accessible."
  echo " - The username and password are correct."
  echo " - The camera supports the specified resolution ($RESOLUTION)."
  echo " - The v4l2loopback module is loaded and the video device ($VIDEO_DEVICE) exists."
  exit 4
}
