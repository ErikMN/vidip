# vidip: Turn a surveillance IP camera into a web camera

Use Video4Linux and GStreamer to turn a surveillance IP camera into a web camera for use with Teams and Skype etc.<br/>

* This script is intended for Linux systems.
* Currently supports Axis as vendor.

## Requirements

These Video4Linux and GStreamer packages:

Debian/Ubuntu:

```sh
sudo apt install v4l-utils v4l2loopback-dkms gstreamer1.0-tools
```

Fedora:

```sh
sudo dnf install v4l-utils akmod-v4l2loopback gstreamer1-plugins-base
```

## Install

To install the script run (as root):

```sh
make install
```

## Usage

Set environment credentials: ```CAMERA_USER``` and ```CAMERA_PASS```

```sh
Usage: ./vidip.sh [options] <IP_ADDRESS or last 3 digits>
Options:
  -l, --load     Load a new v4l2loopback device
  -u, --unload   Unload all v4l2loopback devices with 'v4l2-ip-camera-*' labels
  -c, --check    Check and list all loaded v4l2-ip-camera v4l2loopback devices
  -h, --help     Show this help message
  -v, --version  Show script version

Examples:
  ./vidip.sh -l           # Adds a new /dev/videoX labeled v4l2-ip-camera-X
  ./vidip.sh 192.168.0.90 # Streams from that IP into the first free v4l2-ip-camera device
  ./vidip.sh 90           # Same as above, but uses default IP prefix: 192.168.0.90
```

Test it here: <https://webcamtests.com/> <br/>
Or locally with ```ffplay /dev/video0```

<img src="img/ip_camera1.webp" width="400" alt="logo"/>

Image generated with DALL·E
