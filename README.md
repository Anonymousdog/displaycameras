# displaycameras

displaycameras is a set of scripts run as a service on Raspberry Pi hardware to locally display RTSP streams from IP security cameras. It displays each configured feed in a grid of windows on a locally attached display.

> **64-bit Raspberry Pi OS (Bookworm/Trixie) support:** This branch (`feature/mpv-64bit`) replaces omxplayer with **mpv**, enabling full support on 64-bit ARM. omxplayer was removed from Raspberry Pi OS in Bullseye/Bookworm. See [Key Differences](#key-differences-from-omxplayer-branch) below.

## Donations
If you feel compelled to contribute to the project, feel free to send funds to https://www.paypal.me/anonymousdog

---

# Pre-requisites

* Raspberry Pi hardware
* **64-bit Raspberry Pi OS (Bookworm or Trixie)** — this branch targets ARM64
* systemd init system
* Raspbian Lite is **STRONGLY** recommended
* A locally attached display (HDMI)

## Required packages

The install script handles this automatically. To install manually:

```bash
sudo apt-get install -y mpv socat wmctrl xserver-xorg-core xserver-xorg xinit openbox x11-utils x11-xserver-utils procps
```

`socat` is required by `mpv_ipccontrol` to communicate with mpv's IPC socket.
`wmctrl` is required for camera rotation (repositions mpv windows via X11).

## X11 requirement

mpv requires an X11 display server for multi-window output. The install script sets up a minimal X11 + openbox service automatically. To set it up manually:

```bash
# Create /etc/systemd/system/xorg.service
sudo systemctl enable xorg
sudo systemctl start xorg

# Verify
DISPLAY=:0 xdpyinfo | head -3
```

displaycameras will not start without X11 running (`Requires=xorg.service` in the unit file).

---

# Download/Install/Upgrade/Remove

## Download the Archive
### Latest Release (recommended)
Go to https://github.com/Anonymousdog/displaycameras/releases/latest and download the Source Code (tar.gz) file

### Latest Commits (only when directed)
Download https://github.com/Anonymousdog/displaycameras/archive/feature/mpv-64bit.tar.gz

## Unpack the Archive
1. `tar -xvzf ./<source_code.tar.gz>`
2. `cd ./<source_code directory>`

## Make the Installer Executable
```bash
chmod u+x ./install.sh
```

## Installation
```bash
sudo ./install.sh
```

The installer will:
- Install mpv, socat, xserver-xorg, openbox
- Copy scripts to `/usr/bin/`
- Copy config files to `/etc/displaycameras/`
- Create and enable the `xorg.service` systemd unit
- Enable the `displaycameras.service` systemd unit

## Upgrade
```bash
sudo ./install.sh upgrade
```

No changes will be made to your existing config files or cron job.

## Removal
1. Stop and disable the service:
   ```bash
   sudo systemctl stop displaycameras
   sudo systemctl disable displaycameras
   sudo systemctl stop xorg
   sudo systemctl disable xorg
   ```
2. Remove files:
   ```bash
   sudo rm -R /etc/displaycameras
   sudo rm /etc/systemd/system/displaycameras.service
   sudo rm /etc/systemd/system/xorg.service
   sudo rm /usr/bin/displaycameras /usr/bin/mpv_ipccontrol /usr/bin/rotatedisplays /usr/bin/black.png
   sudo rm /etc/cron.d/repaircameras && sudo systemctl restart cron
   ```
3. Remove packages (optional):
   ```bash
   sudo apt-get purge mpv socat -y && sudo apt-get autoremove -y
   ```

---

# CONFIGURATION

Edit `/etc/displaycameras/displaycameras.conf` and `/etc/displaycameras/layout.conf.default` for your environment.

## Minimal Configuration

### Global Options (`displaycameras.conf`)
| Variable | Description |
|----------|-------------|
| `stream_timeout` | Network timeout in seconds (default: 30). Old name `omx_timeout` still works. |
| `startsleep` | Seconds to wait after launching each mpv instance |
| `feedsleep` | Seconds to wait before checking feed playback position |
| `retry` | Max retries for startup and feed checks |
| `blank` | _(removed)_ Screen blanking is automatic under X11 |
| `rotate` | Set `"true"` to enable camera rotation |
| `rotatedelay` | Seconds between rotation steps |
| `displaydetect` | Set `"true"` to auto-detect display resolution |
| `video_rotate` | Rotate video output for sideways-mounted cameras. Valid values: `0`, `90`, `180`, `270` |
| `disable_audio` | Set `"false"` to enable audio from camera streams (default: `"true"` — audio disabled) |
| `mpv_extra_opts` | Extra mpv flags appended to every camera instance (e.g. `"--vo=x11"`) |

### Camera and Window Layout (`layout.conf.default`)
- Define `windows`, `window_positions`, `camera_names`, and `camera_feeds`
- Window positions use omxplayer format `"x1 y1 x2 y2"` — converted automatically to mpv geometry

**Example (6-camera 3×2 grid on 1920×1080):**
```bash
window_positions=(
"0 0 639 359"
"640 0 1279 359"
"1280 0 1919 359"
"0 360 639 719"
"640 360 1279 719"
"1280 360 1919 719"
)
camera_names=(cam1 cam2 cam3 cam4 cam5 cam6)
camera_feeds=(
"rtsp://192.168.1.10/stream"
"rtsp://192.168.1.11/stream"
...
)
```

### Camera Name Restrictions
Camera names must be valid for use as filenames (used for PID files and IPC sockets). Stick to `[A-Za-z0-9_-]` and do not start with a digit.

---

# TESTING

## Manual test
```bash
sudo /usr/bin/displaycameras start
sudo /usr/bin/displaycameras status
sudo /usr/bin/displaycameras stop
```

Adjust `feedsleep` upward if you see playback retries. Adjust `startsleep` upward if you see startup retries.

## Developer test environment (Docker)

Test the full rewrite locally before deploying to the Pi. The `dev/` folder contains an ARM64 Docker environment with a virtual display accessible in your browser.

**Base image:** `vascoguita/raspios:arm64` — built from the official Raspberry Pi OS Lite rootfs, the closest match to the real Pi environment.

**Display stack:** TigerVNC (`Xvnc`) + noVNC + websockify — virtual display accessible via browser at port 6080.

### Build and start
```bash
cd dev/
docker compose up -d --build
```

`--build` forces a rebuild of the image. `-d` runs the container in the background.

Open **http://localhost:6080/vnc.html** to see the virtual display.

> **Note:** Port mapping warnings (`Published ports are discarded when using host network mode`) are expected and harmless — the container uses `network_mode: host` to reach cameras on your LAN.

### Run automated tests
```bash
docker exec -it displaycameras-dev bash /tests/run_tests.sh
```

### Interactive shell
```bash
docker exec -it displaycameras-dev bash
# then inside:
displaycameras start
displaycameras status
displaycameras stop
```

### Stop the container
```bash
docker compose down
```

### Switch to live camera feeds
Edit `dev/config/layout.conf.default` — comment out the TEST MODE block and uncomment the LIVE MODE block with your real RTSP URLs. The container uses `network_mode: host` so it can reach cameras on your LAN directly.

### CPU usage note
On x86 hosts, the ARM64 container runs under QEMU emulation (~10-20x slower). Expect high CPU (~600%+), IPC timeouts, and inflated resource usage. On native ARM64 hosts (Apple Silicon, ARM Linux), Docker runs without emulation and resource usage will be closer to real hardware.

Either way, use the Docker environment for **logical testing only** (script flow, flag checks, geometry conversion, IPC commands). To measure actual per-stream CPU and RAM, hardware decode behavior, and max camera capacity, test on a real Raspberry Pi.

## Debugging

### Check status of all feeds
```bash
sudo /usr/bin/displaycameras status
```

### Live dashboard (refreshes every 5s)
```bash
sudo /usr/bin/displaycameras observe
```
Shows camera name, play status, uptime, and restart count.

### View log files and restart counts
```bash
sudo /usr/bin/displaycameras logs
```

### Enable verbose mpv logging for one camera
```bash
sudo /usr/bin/displaycameras debug <camera_name> on
# view output:
tail -f /var/log/displaycameras/mpv-<camera_name>.log
# disable:
sudo /usr/bin/displaycameras debug <camera_name> off
```

### Verify mpv can play a feed directly
```bash
DISPLAY=:0 mpv --rtsp-transport=tcp --no-terminal <camera_feed_URL>
```

### Check IPC command log
```bash
tail -f /var/log/displaycameras/ipc.log
```

---

# Managing the Service

```bash
sudo systemctl start displaycameras
sudo systemctl stop displaycameras
sudo systemctl restart displaycameras
sudo systemctl status displaycameras
```

### Repair (restart failed feeds without full restart)
```bash
sudo systemctl reload displaycameras
# or directly:
sudo /usr/bin/displaycameras repair
```

---

# Advanced Configurations

## Display Detection
Enable `displaydetect="true"` in `displaycameras.conf` and create layout files named `/etc/displaycameras/layout.conf.<resolution>` (e.g., `layout.conf.1920x1080`).

## Rotation
To rotate more cameras through fewer windows, set `rotate="true"` in `displaycameras.conf` and ensure you have at least as many `window_positions` as `camera_names`.

> **Note:** mpv's `geometry` property can be updated at runtime via IPC, so rotation repositions windows without restarting the player. Streams continue playing during rotation.

## Display Blanking
Screen blanking is handled automatically — X11 starts with a black root window, hiding console output. The `blank` config option (which used `fbi`) has been removed since `fbi` does not work under X11+KMS. Screen saver and DPMS are disabled via `xset` in the openbox autostart.

## Bookworm / KMS display notes
Raspberry Pi OS Bookworm uses full KMS (`vc4-kms-v3d`). If you see a black screen when X11 starts, add an explicit xorg config:

```bash
# /etc/X11/xorg.conf.d/99-vc4.conf
Section "Device"
    Identifier "vc4"
    Driver     "modesetting"
    Option     "AccelMethod" "glamor"
EndSection
```

To prevent screen blanking during camera display, add to `/etc/xdg/openbox/autostart`:
```bash
xset -dpms
xset s noblank
xset s off
```

---

# Troubleshooting

## OpenGL errors / camera restarts in a loop

If you see repeated errors like the following in a camera's log file:

```
[vo/gpu/opengl] after rendering: OpenGL error INVALID_OPERATION.
```

...and the camera feed keeps restarting every few seconds, your Pi's GPU driver is not compatible with mpv's default OpenGL video output. This is common on non-standard or small HDMI displays (e.g. 800×480).

**Fix:** add `--vo=x11` to `mpv_extra_opts` in `/etc/displaycameras/displaycameras.conf`:

```bash
mpv_extra_opts="--vo=x11"
```

This switches mpv to a pure software X11 video output (no OpenGL required). CPU usage will be slightly higher but the feed will play reliably.

After editing, restart the service:
```bash
sudo systemctl restart displaycameras
```

## Camera feed is rotated / portrait instead of landscape

If your camera is physically mounted sideways and the feed appears rotated, set `video_rotate` in `/etc/displaycameras/displaycameras.conf`:

```bash
video_rotate=270   # or 90, 180 depending on your mount
```

> **Note:** `rotate="true"` is for cycling camera feeds through windows — it does not affect video orientation.

## Camera feed shows as a small window instead of fullscreen

If your display uses OS-level rotation (e.g. via `display_rotate` in `/boot/config.txt`), the effective resolution seen by X11 may be rotated. For example, an 800×480 display rotated 90° becomes 480×800 in X11.

Your `window_positions` in the layout config must match the **post-rotation** resolution. Check your effective resolution with:

```bash
DISPLAY=:0 xdpyinfo | grep dimensions
```

Then adjust your layout config accordingly. For a 480×800 effective resolution:

```
window_positions=(
"0 0 479 799"
)
```

---

# Key Differences from omxplayer Branch

| | omxplayer (legacy) | mpv (this branch) |
|--|--|--|
| OS support | 32-bit Buster only | 64-bit Bookworm |
| Display output | Framebuffer (no X needed) | X11 (`DISPLAY=:0`) |
| Window position | `--win "x1 y1 x2 y2"` | `--geometry=WxH+X+Y` (auto-converted) |
| Hardware decode | OpenMAX IL | `--hwdec=auto-safe` |
| Health check | DBUS via `omxplayer_dbuscontrol` | IPC socket via `mpv_ipccontrol` + socat |
| Screen blanking | `fbi` | Automatic (X11 black root window) |
| Control script | `omxplayer_dbuscontrol` | `mpv_ipccontrol` |
| Logging | None | Per-camera logs + IPC log + restart counters |
| New commands | — | `observe`, `debug`, `logs` |

Config files (`displaycameras.conf`, `layout.conf.*`) are **unchanged** — no migration needed.

## Performance Note

omxplayer decoded video on the Broadcom VideoCore GPU and rendered via a hardware overlay (DispmanX), using ~5% CPU. mpv decodes through X11 and uses more CPU for both decode and display compositing.

Hardware decode is detected automatically: on Pi 3/4, the script uses `--hwdec=v4l2m2m-copy` (H.264 decode via the bcm2835-codec GPU driver, ~5-10% CPU per stream). On Pi 5 (no H.264 hardware decoder), it falls back to `--hwdec=auto-safe` (software decode).

**Built-in optimizations:** The script applies several mpv flags automatically to reduce CPU, GPU, and memory usage on the Pi:
- Audio disabled by default (`disable_audio="true"` in config) — saves ~3-5% CPU per stream
- Minimal cache (`--no-cache --demuxer-max-bytes=512K`) — saves ~150MB RAM per stream (mpv default is 150MB)
- Cheap GPU scaling (`--scale=bilinear --dscale=bilinear --dither=no`) — saves ~3-5% GPU per stream
- UI stripped (`--no-osc --no-osd-bar --no-input-default-bindings`) — saves ~1-2% per stream
- Fast stream init (`--demuxer-lavf-analyzeduration=0.1 --demuxer-lavf-probesize=32768`)

Combined savings: ~10-15% CPU per stream and ~150MB RAM per stream. For a 4-camera setup, this means ~40-60% less CPU and ~600MB less RAM versus unoptimized mpv defaults.

To re-enable audio (e.g. for a camera with a microphone), set `disable_audio="false"` in `displaycameras.conf`. To override any optimization flag, use `mpv_extra_opts` (mpv uses last-wins for duplicate flags).

**Pi 5 users:** The Pi 5 has no H.264 hardware decoder but does have an HEVC (H.265) hardware decoder. If your cameras support H.265 streams (most modern Hikvision, Dahua, Reolink, Ubiquiti cameras do), configure them to output H.265 — mpv will automatically use hardware decode via `drm-copy`, significantly reducing CPU usage.

Expect higher CPU usage on this branch than omxplayer. Recommended hardware:

| Hardware | Cameras | Notes |
|----------|---------|-------|
| Pi 5 (2.4GHz, 4GB+) | 6-8 at 720p | H.264 software decode. Use H.265 streams for hardware decode. |
| Pi 4 (1.5GHz, 4GB+) | 4-6 at 720p | H.264 hardware decode via v4l2m2m. 1080p: 2-4 feeds. |
| Pi 3 (1.2GHz, 1GB) | 2-3 at 720p | H.264 hardware decode via v4l2m2m. Increase `startsleep`/`feedsleep`. |
| Pi Zero 2W (1GHz, 512MB) | Not recommended | 512MB is too tight for X11 + mpv. Single stream may work briefly but degrades over time. |

If feeds freeze or restart in a loop, your Pi is CPU-starved. Lower camera stream resolution, reduce the number of feeds, or upgrade to a Pi 4.
