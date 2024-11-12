# vidip: Turn a surveillance IP camera into a web camera

Use Video4Linux and GStreamer to turn a surveillance IP camera into a web camera. <br/>
Currently only works on Axis branded cameras. <br/>

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

<img src="img/ip_camera1.webp" width="400" alt="logo"/>

Image generated with DALL·E
