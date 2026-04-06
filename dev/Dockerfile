FROM --platform=linux/arm64 vascoguita/raspios:arm64

ENV DEBIAN_FRONTEND=noninteractive
ENV container=docker

RUN apt-get update && apt-get install -y \
    # Player and IPC (matches install.sh)
    mpv \
    socat \
    wmctrl \
    # X11 utilities (xset, xdpyinfo)
    x11-utils \
    x11-xserver-utils \
    # Virtual display + VNC (tigervnc bundles X server + VNC in one)
    tigervnc-standalone-server \
    websockify \
    # Test video generation
    ffmpeg \
    # Utilities
    procps \
    cron \
    bash \
    openbox \
    python3-xdg \
    menu \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Mask units that don't work in a container (systemd 257 + QEMU emulation)
# Core fixes: credential-based services fail under QEMU, remount-fs has no real mounts
RUN systemctl mask \
    # systemd core that fails in containers (credential/mount issues)
    systemd-firstboot.service \
    systemd-journald.service systemd-journald.socket systemd-journald-dev-log.socket \
    systemd-tmpfiles-setup.service systemd-tmpfiles-setup-dev.service systemd-tmpfiles-setup-dev-early.service \
    systemd-remount-fs.service \
    systemd-sysctl.service \
    systemd-sysusers.service \
    systemd-udev-load-credentials.service \
    systemd-growfs-root.service \
    # Pi OS services not needed in container
    cloud-init.service cloud-init-local.service cloud-init-network.service cloud-config.service cloud-final.service \
    nftables.service \
    systemd-networkd.service systemd-networkd.socket systemd-network-generator.service \
    systemd-resolved.service \
    getty@.service serial-getty@.service console-getty.service \
    e2scrub_reap.service \
    ModemManager.service NetworkManager.service wpa_supplicant.service \
    rpi-eeprom-update.service rpi-usb-gadget-ics.service \
    userconfig.service sshswitch.service ssh.service avahi-daemon.service \
    systemd-journal-flush.service

# Empty fstab — Pi OS references physical partitions that block boot in a container
RUN echo "# empty — container has no physical partitions" > /etc/fstab

# Ensure 'pi' user exists (Pi OS already has it, but guard for other base images)
RUN id pi &>/dev/null || useradd -m -s /bin/bash pi

# Create /tmp and /run dirs that systemd-tmpfiles-setup would normally create
RUN mkdir -p /run/systemd /run/dbus /tmp/.X11-unix /var/run/displaycameras

# Install mediamtx (lightweight RTSP server for local test streams)
RUN wget -qO- https://github.com/bluenviron/mediamtx/releases/download/v1.9.0/mediamtx_v1.9.0_linux_arm64v8.tar.gz \
    | tar xz -C /usr/local/bin mediamtx

# Install noVNC directly from GitHub (avoids broken apt package)
RUN mkdir -p /usr/share/novnc && \
    wget -qO- https://github.com/novnc/noVNC/archive/refs/tags/v1.4.0.tar.gz \
    | tar xz --strip-components=1 -C /usr/share/novnc

# Install scripts (from repo root — build context is ../)
COPY displaycameras    /usr/bin/displaycameras
COPY mpv_ipccontrol    /usr/bin/mpv_ipccontrol
COPY rotatedisplays    /usr/bin/rotatedisplays
RUN chmod 0755 /usr/bin/displaycameras /usr/bin/mpv_ipccontrol /usr/bin/rotatedisplays

# Install config
RUN mkdir -p /etc/displaycameras
COPY dev/config/displaycameras.conf       /etc/displaycameras/displaycameras.conf
COPY dev/config/layout.conf.default       /etc/displaycameras/layout.conf.default

# Install displaycameras.service (real unit, same as on Pi)
COPY displaycameras.service /etc/systemd/system/displaycameras.service

# Create xorg.service (Xvnc variant — runs as 'pi' like real Pi's startx)
# Uses -ac to allow cross-user X11 connections (root displaycameras → pi's X server)
# Without -ac: mpv gets "Authorization required" — the exact bug we're testing for
RUN cat > /etc/systemd/system/xorg.service <<'EOF'
[Unit]
Description=X11 Display Server (Xvnc for dev)
After=network.target

[Service]
Type=simple
User=pi
ExecStart=/usr/bin/Xvnc :0 -geometry 1920x1080 -depth 24 -rfbport 5900 -SecurityTypes None -ac
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Create openbox service (starts after X11)
RUN cat > /etc/systemd/system/openbox.service <<'EOF'
[Unit]
Description=Openbox Window Manager
After=xorg.service
Requires=xorg.service

[Service]
Type=simple
Environment=DISPLAY=:0
ExecStart=/usr/bin/openbox-session
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# Create noVNC service (browser access)
RUN cat > /etc/systemd/system/novnc.service <<'EOF'
[Unit]
Description=noVNC web client
After=xorg.service

[Service]
Type=simple
ExecStart=/usr/bin/websockify --web /usr/share/novnc 6080 localhost:5900
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# mediamtx config (RTSP server — 4 streams matching test layout)
RUN mkdir -p /etc/mediamtx && cat > /etc/mediamtx/mediamtx.yml <<'EOF'
logLevel: warn
paths:
  cam1:
    source: publisher
  cam2:
    source: publisher
  cam3:
    source: publisher
  cam4:
    source: publisher
EOF

# mediamtx.service — RTSP server
RUN cat > /etc/systemd/system/mediamtx.service <<'EOF'
[Unit]
Description=MediaMTX RTSP Server
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/mediamtx /etc/mediamtx/mediamtx.yml
Restart=on-failure
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

# mediamtx-feeds.service — ffmpeg pushes test video to each RTSP stream
RUN cat > /etc/systemd/system/mediamtx-feeds.service <<'EOF'
[Unit]
Description=Push test video to RTSP streams
After=mediamtx.service
Requires=mediamtx.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStartPre=/bin/sleep 2
ExecStart=/bin/bash -c '\
  for i in 1 2 3 4; do \
    ffmpeg -re -stream_loop -1 -i /test/test.mp4 \
      -c copy -f rtsp rtsp://localhost:8554/cam$i \
      </dev/null >/dev/null 2>&1 & \
  done; \
  echo "All 4 RTSP feeds started"'
ExecStop=/bin/bash -c 'pkill -f "ffmpeg.*rtsp://localhost:8554"'

[Install]
WantedBy=multi-user.target
EOF

# Enable all services
RUN systemctl enable xorg openbox novnc cron displaycameras mediamtx mediamtx-feeds

# Openbox config — disable window decorations for mpv + disable screen blanking
RUN mkdir -p /root/.config/openbox /etc/xdg/openbox
COPY dev/config/openbox-rc.xml           /root/.config/openbox/rc.xml
RUN printf '#!/bin/sh\nxset -dpms 2>/dev/null || true\nxset s noblank 2>/dev/null || true\nxset s off 2>/dev/null || true\n' > /etc/xdg/openbox/autostart && \
    chmod +x /etc/xdg/openbox/autostart

# Generate test video (480x360 4:3 in 640x360 16:9 windows — exposes aspect ratio bugs, 60s loop)
RUN mkdir -p /test && \
    ffmpeg -f lavfi -i testsrc=size=480x360:rate=25 -t 60 /test/test.mp4 -y -loglevel quiet

# Install cron job (matches real Pi install)
COPY repaircameras.cron /etc/cron.d/repaircameras
RUN chmod 0644 /etc/cron.d/repaircameras

# Mock /boot/firmware (Bookworm path for displaydetect)
RUN mkdir -p /boot/firmware && \
    echo "disable_overscan=1" > /boot/firmware/config.txt

# PID and log dirs
RUN mkdir -p /var/run/displaycameras /var/log/displaycameras

EXPOSE 6080

CMD ["/sbin/init"]
