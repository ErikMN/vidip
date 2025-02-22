#!/usr/bin/env sh
#
# Turn an IP camera into a web camera, dependencies (Debian/Ubuntu and Fedora):
# sudo apt install v4l-utils v4l2loopback-dkms gstreamer1.0-tools
# sudo dnf install v4l-utils akmod-v4l2loopback gstreamer1-plugins-base
#
# Supported vendors:
# - Axis
#
# Test it here:
# https://webcamtests.com/
# ffplay /dev/video0
#
# GitHub:
#   https://github.com/ErikMN/vidip
#
# License:
#   MIT License
#
set -eu

VERSION="1.1.0"

#==============================================================================#

# Set DEBUG from env:
DEBUG="${DEBUG:-false}"
DEBUG_ENV=""
DEBUG_ARGS=""

# V4L parameters:
MODULE_NAME="v4l2loopback"
V4L_LABEL="v4l2-ip-camera"

# Device parameters:
RESOLUTION="1280x720"
CAMERA_USER="${CAMERA_USER:-root}"
CAMERA_PASS="${CAMERA_PASS:-pass}"
DEFAULT_IP_PREFIX="192.168.0."

# Print colors:
FMT_GREEN=$(printf '\033[32m')
FMT_YELLOW=$(printf '\033[33m')
FMT_RED=$(printf '\033[31m')
FMT_BLUE=$(printf '\033[34m')
FMT_BOLD=$(printf '\033[1m')
FMT_RESET=$(printf '\033[0m')

#==============================================================================#
# Helpers:

# Trap SIGINT:
trap 'echo "${FMT_YELLOW}\nScript interrupted. Exiting.${FMT_RESET}"; exit 0' INT

# Return a space-separated list of device numbers ("0 2 3") with a label matching V4L_LABEL:
get_loaded_devices() {
  LOADED=""
  for dev in /dev/video*; do
    if v4l2-ctl -d "$dev" --all 2>/dev/null | grep -q "$V4L_LABEL-"; then
      devnum="${dev#/dev/video}"
      LOADED="$LOADED $devnum"
    fi
  done
  echo "$LOADED" | awk '{$1=$1;print}'
}

# Return the first free device number in range 0..63 not in the current LOADED list:
get_next_free_device_number() {
  LOADED="$1"
  i=0
  while [ $i -lt 64 ]; do
    # Skip If /dev/video$i exists OR $i is in the LOADED list:
    if [ -e "/dev/video$i" ] || echo "$LOADED" | grep -qw "$i"; then
      i=$((i + 1))
      continue
    fi
    echo "$i"
    return
  done
  echo "-1"
}

# Check if the v4l module is loaded:
is_module_loaded() {
  [ -d "/sys/module/$MODULE_NAME" ]
}

# Check if a /dev/videoX is in use by any process (using fuser from psmisc):
is_device_in_use() {
  device_num="$1"
  fuser "/dev/video${device_num}" >/dev/null 2>&1
}

# Usage function:
show_usage() {
  echo "Usage: $0 [options] <IP_ADDRESS or last 3 digits>"
  echo "Options:"
  echo "  -l, --load     Load a new v4l2loopback device"
  echo "  -u, --unload   Unload all v4l2loopback devices with '$V4L_LABEL-*' labels"
  echo "  -c, --check    Check and list all loaded $V4L_LABEL v4l2loopback devices"
  echo "  -h, --help     Show this help message"
  echo "  -v, --version  Show script version"
  echo
  echo "Examples:"
  echo "  $0 -l           # Adds a new /dev/videoX labeled $V4L_LABEL-X"
  echo "  $0 192.168.0.90 # Streams from that IP into the first free $V4L_LABEL device"
  echo "  $0 90           # Same as above, but uses default IP prefix: 192.168.0.90"
}

#==============================================================================#
# v4l2loopback section:

# Load a new v4l2loopback device:
load_module() {
  # Require sudo/root to load:
  if [ "$(id -u)" -ne 0 ]; then
    echo "${FMT_RED}Error: Must run as root (use sudo) to load the module.${FMT_RESET}"
    exit 1
  fi

  # Get a free device to use:
  LOADED="$(get_loaded_devices)"
  NEXT_FREE="$(get_next_free_device_number "$LOADED")"
  if [ "$NEXT_FREE" = "-1" ]; then
    echo "${FMT_RED}No free device numbers left (0..63 all used).${FMT_RESET}"
    exit 2
  fi

  NEW_LIST="$LOADED $NEXT_FREE"
  NEW_LIST="$(echo "$NEW_LIST" | awk '{$1=$1;print}')"

  # NOTE: Need to first remove the v4l2loopback module to add a new device:
  unload_module

  # Build device and label list:
  VIDEO_NR_LIST=""
  LABEL_LIST=""
  for n in $NEW_LIST; do
    VIDEO_NR_LIST="${VIDEO_NR_LIST},${n}"
    LABEL_LIST="${LABEL_LIST},${V4L_LABEL}-${n}"
  done

  VIDEO_NR_LIST="$(echo "$VIDEO_NR_LIST" | sed 's/^,//')"
  LABEL_LIST="$(echo "$LABEL_LIST" | sed 's/^,//')"

  # Load the v4l2loopback module with a new device:
  echo "${FMT_BLUE}Loading $MODULE_NAME with devices=$VIDEO_NR_LIST${FMT_RESET}"
  if ! modprobe "$MODULE_NAME" video_nr="$VIDEO_NR_LIST" card_label="$LABEL_LIST" exclusive_caps=1; then
    echo "${FMT_RED}Failed to load $MODULE_NAME module with new device(s).${FMT_RESET}"
    exit 2
  fi

  if is_module_loaded; then
    # Find the device number assigned to the new label:
    assigned_dev=-1
    for dev in /dev/video*; do
      if v4l2-ctl -d "$dev" --all 2>/dev/null | grep -q "${V4L_LABEL}-${NEXT_FREE}"; then
        assigned_dev="${dev#/dev/video}"
        break
      fi
    done
    # Check if the new device was added successfully:
    if [ "$assigned_dev" = "-1" ]; then
      echo "${FMT_RED}Could not find the newly assigned device for label ${V4L_LABEL}-${NEXT_FREE}.${FMT_RESET}"
    else
      echo "${FMT_BOLD}${FMT_GREEN}v4l2loopback loaded successfully with new device /dev/video${assigned_dev} (label: ${V4L_LABEL}-${NEXT_FREE})${FMT_RESET}"
    fi
  else
    echo "${FMT_RED}Failed to load $MODULE_NAME module with new device.${FMT_RESET}"
    exit 2
  fi
}

# Unload the v4l2loopback module:
unload_module() {
  # Require root to unload:
  if [ "$(id -u)" -ne 0 ]; then
    echo "${FMT_RED}Error: Must run as root (use sudo) to unload the module.${FMT_RESET}"
    exit 1
  fi

  # Exit function if the module is not loaded:
  if ! is_module_loaded; then
    echo "${FMT_BOLD}No $MODULE_NAME module loaded. Skipping unload.${FMT_RESET}"
    return 0
  fi

  # Get a list of loaded devices:
  LOADED="$(get_loaded_devices)"
  if [ -z "$LOADED" ]; then
    echo "${FMT_BOLD}v4l2loopback is loaded but no $V4L_LABEL devices found. Removing anyway...${FMT_RESET}"
    if ! modprobe -r "$MODULE_NAME"; then
      echo "${FMT_RED}Failed to unload $MODULE_NAME module.${FMT_RESET}"
      exit 3
    fi
    if ! is_module_loaded; then
      echo "${FMT_BOLD}${FMT_GREEN}All $V4L_LABEL devices removed successfully.${FMT_RESET}"
    else
      echo "${FMT_RED}Failed to unload $MODULE_NAME module.${FMT_RESET}"
      exit 3
    fi
    return 0
  fi

  # Check if any loaded device are in use:
  FREE_DEVICES=""
  INUSE_DEVICES=""
  for n in $LOADED; do
    if is_device_in_use "$n"; then
      INUSE_DEVICES="$INUSE_DEVICES $n"
    else
      FREE_DEVICES="$FREE_DEVICES $n"
    fi
  done

  # If no devices are in use, remove the module entirely:
  if [ -z "$INUSE_DEVICES" ]; then
    echo "${FMT_YELLOW}No devices in use. Removing $MODULE_NAME entirely.${FMT_RESET}"
    if ! modprobe -r "$MODULE_NAME"; then
      echo "${FMT_RED}Failed to unload $MODULE_NAME module.${FMT_RESET}"
      exit 3
    fi
    if ! is_module_loaded; then
      echo "${FMT_BOLD}${FMT_GREEN}All $V4L_LABEL devices removed successfully.${FMT_RESET}"
    else
      echo "${FMT_RED}Failed to unload $MODULE_NAME module.${FMT_RESET}"
      exit 3
    fi
  else
    echo "${FMT_RED}Some devices are in use: $INUSE_DEVICES. Skipping removal.${FMT_RESET}"
    echo "Close or kill any processes using those devices and try again."
    exit 4
  fi
}

# Check loaded module and devices:
check_module() {
  if ! is_module_loaded; then
    echo "${FMT_BOLD}${FMT_YELLOW}No $MODULE_NAME module loaded.${FMT_RESET}"
    echo "Please load it by running this script with the -l or --load option:"
    echo "  sudo $(basename "$0") -l"
    return 1
  fi

  echo "${FMT_GREEN}$MODULE_NAME module is currently loaded with these $V4L_LABEL devices:${FMT_RESET}"
  LOADED="$(get_loaded_devices)"
  if [ -n "$LOADED" ]; then
    for n in $LOADED; do
      echo " - /dev/video${n} (label: $V4L_LABEL-${n})"
    done
  else
    echo " No $V4L_LABEL devices found."
  fi
}

#==============================================================================#
# Application start section:

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
if ! command -v gst-launch-1.0 >/dev/null 2>&1; then
  echo "${FMT_RED}Error: GStreamer tools is not installed.${FMT_RESET}"
  echo "  Debian/Ubuntu: 'sudo apt install gstreamer1.0-tools'"
  echo "  Fedora: 'sudo dnf install gstreamer1-plugins-base'"
  exit 1
fi

# Make sure that v4l-utils is installed:
if ! command -v v4l2-ctl >/dev/null 2>&1; then
  echo "${FMT_RED}Error: v4l-utils is not installed.${FMT_RESET}"
  echo "  Debian/Ubuntu: 'sudo apt install v4l-utils v4l2loopback-dkms'"
  echo "  Fedora: 'sudo dnf install v4l-utils akmod-v4l2loopback'"
  exit 1
fi

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
if ! is_module_loaded; then
  echo "${FMT_RED}$MODULE_NAME module is not loaded.${FMT_RESET}"
  echo "Please run '$0 -l' to create at least one $V4L_LABEL device."
  exit 2
fi

# Find the first free loaded device:
LOADED="$(get_loaded_devices)"
FREE_DEVICE=""
for n in $LOADED; do
  if ! is_device_in_use "$n"; then
    FREE_DEVICE="$n"
    break
  fi
done

# Check that a free device is available:
if [ -z "$FREE_DEVICE" ]; then
  echo "${FMT_RED}No free $V4L_LABEL device found.${FMT_RESET}"
  echo "Please run '$0 -l' to add another device."
  exit 3
fi

# Device to use:
VIDEO_DEVICE="/dev/video${FREE_DEVICE}"

# Verify that the device exists:
if [ ! -e "$VIDEO_DEVICE" ]; then
  echo "${FMT_RED}Device $VIDEO_DEVICE does not exist. Exiting.${FMT_RESET}"
  exit 3
fi

# Check for DEBUG environment variable:
if [ "$DEBUG" = "true" ]; then
  DEBUG_ENV="GST_DEBUG=3"
  DEBUG_ARGS="--verbose"
fi

#==============================================================================#
# Vendor section:

# Axis RTSP URL:
RTSP_URL="rtsp://${CAMERA_USER}:${CAMERA_PASS}@${CAMERA_IP}/axis-media/media.amp?resolution=${RESOLUTION}"

#==============================================================================#
# GStreamer section:

# GStreamer pipeline:
PIPELINE="rtspsrc latency=0 location=${RTSP_URL} ! \
  rtph264depay ! \
  decodebin ! \
  videoconvert ! \
  v4l2sink device=${VIDEO_DEVICE}"

GSTREAMER_CMD="$DEBUG_ENV gst-launch-1.0 $PIPELINE $DEBUG_ARGS"

if [ "$DEBUG" = "true" ]; then
  echo "${FMT_YELLOW}$GSTREAMER_CMD${FMT_RESET}"
fi

# Start streaming:
echo "${FMT_BOLD}${FMT_BLUE}Starting video stream from IP camera at $CAMERA_IP to ${VIDEO_DEVICE}. Press Ctrl+C to stop.${FMT_RESET}"
echo "Test here: https://webcamtests.com/"
if [ "$DEBUG" = "true" ]; then
  sh -c "$GSTREAMER_CMD"
  STATUS=$?
else
  # Only print errors:
  sh -c "$GSTREAMER_CMD" >/dev/null
  STATUS=$?
fi

# Check GStreamer failure:
if [ "$STATUS" -ne 0 ]; then
  echo
  echo "${FMT_RED}Error: Failed to start video stream from IP camera at $CAMERA_IP.${FMT_RESET}"
  echo "Please check the following:"
  echo " - The IP address ($CAMERA_IP) is correct and accessible."
  echo " - The username and password are correct."
  echo " - The camera supports the specified resolution ($RESOLUTION)."
  echo " - The v4l2loopback module is loaded and the video device ($VIDEO_DEVICE) exists."
  echo " - Global proxy settings"
  exit 4
fi

#==============================================================================#
