# vidip: Turn a surveillance IP camera into a web camera

Use Video4Linux and GStreamer to turn a surveillance IP camera into a web camera for use with Teams and Skype etc.<br/>
Currently only works on Axis branded cameras. <br/>
This script is intended for Linux systems.

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
  -l, --load     Load the v4l2loopback module
  -u, --unload   Unload the v4l2loopback module
  -c, --check    Check if the v4l2loopback module is loaded
  -h, --help     Show this help message
```

Test it here: <https://webcamtests.com/>

<img src="img/ip_camera1.webp" width="400" alt="logo"/>

Image generated with DALL·E
