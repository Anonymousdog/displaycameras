#!/bin/bash
# Install displaycameras with mpv for 64-bit Raspberry Pi OS (Bookworm/Trixie)

DIR=$(dirname "$(readlink -f "$0")")

# Install prerequisites
for package in mpv socat wmctrl xserver-xorg-core xserver-xorg xinit openbox x11-utils x11-xserver-utils procps; do
    if [ "$(dpkg-query -s $package 2>/dev/null | grep Status | awk '{print $4}')" != "installed" ]; then
        apt-get install $package -y
    fi
done

# Copy main script
if [ -r $DIR/displaycameras ]; then
    echo "Copying main script."
    cp -f $DIR/displaycameras /usr/bin/ && chown root:root /usr/bin/displaycameras && chmod 0755 /usr/bin/displaycameras
else
    echo "displaycameras missing. Verify package contents."; exit 1
fi

# Copy systemd service
if [ -r $DIR/displaycameras.service ]; then
    echo "Copying systemd service."
    cp -f $DIR/displaycameras.service /etc/systemd/system/ && chown root:root /etc/systemd/system/displaycameras.service && chmod 0644 /etc/systemd/system/displaycameras.service
else
    echo "displaycameras.service missing. Verify package contents."; exit 2
fi

# Config and cron (skip if upgrading)
if [ "$1" != "upgrade" ]; then
    if [ -r $DIR/displaycameras.conf ]; then
        if [ -r /etc/displaycameras/displaycameras.conf ]; then
            [ -d /etc/displaycameras/bak ] || mkdir /etc/displaycameras/bak
            for f in $(find /etc/displaycameras/ -maxdepth 1 -type f); do
                mv -f $f /etc/displaycameras/bak/
            done
            echo "Existing config backed up to /etc/displaycameras/bak"
        fi
        echo "Copying config files."
        [ -d /etc/displaycameras ] || mkdir /etc/displaycameras
        cp -f $DIR/layout.conf.default /etc/displaycameras/ && chown root:root /etc/displaycameras/layout.conf.default && chmod 0644 /etc/displaycameras/layout.conf.default
        cp -f $DIR/displaycameras.conf /etc/displaycameras/ && chown root:root /etc/displaycameras/displaycameras.conf && chmod 0644 /etc/displaycameras/displaycameras.conf
    else
        echo "displaycameras.conf missing. Verify package contents."; exit 3
    fi

    if [ -r $DIR/repaircameras.cron ]; then
        echo "Installing repair cron job."
        cp -f $DIR/repaircameras.cron /etc/cron.d/repaircameras && chown root:root /etc/cron.d/repaircameras && chmod 0755 /etc/cron.d/repaircameras
        systemctl restart cron
    else
        echo "repaircameras.cron missing. Verify package contents."; exit 4
    fi

    # Disable overscan for display detection
    if [ "$(raspi-config nonint get_overscan 2>/dev/null)" = "0" ]; then
        echo "Disabling display overscan."
        raspi-config nonint do_overscan 1
    fi

    # Set up X11 autostart service
    echo "Setting up X11 systemd service."
    cat > /etc/systemd/system/xorg.service <<'XORG_EOF'
[Unit]
Description=X11 Display Server
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/bin/startx /usr/bin/openbox-session -- :0 vt7 -ac -nocursor
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
XORG_EOF
    systemctl daemon-reload
    systemctl enable xorg

    # Set up openbox config — disable window decorations for mpv windows
    echo "Setting up openbox config."
    mkdir -p /root/.config/openbox
    cat > /root/.config/openbox/rc.xml <<'OPENBOX_EOF'
<?xml version="1.0" encoding="UTF-8"?>
<openbox_config xmlns="http://openbox.org/3.4/rc">
  <applications>
    <application class="*" name="mpv">
      <decor>no</decor>
      <focus>no</focus>
    </application>
  </applications>
</openbox_config>
OPENBOX_EOF

    # Disable screen blanking and DPMS via openbox autostart
    echo "Disabling screen blanking in openbox autostart."
    mkdir -p /etc/xdg/openbox
    cat > /etc/xdg/openbox/autostart <<'AUTOSTART_EOF'
xset -dpms
xset s noblank
xset s off
AUTOSTART_EOF
fi

# Copy mpv_ipccontrol (replaces omxplayer_dbuscontrol)
if [ -r $DIR/mpv_ipccontrol ]; then
    echo "Copying mpv IPC control script."
    cp -f $DIR/mpv_ipccontrol /usr/bin/ && chown root:root /usr/bin/mpv_ipccontrol && chmod 0755 /usr/bin/mpv_ipccontrol
else
    echo "mpv_ipccontrol missing. Verify package contents."; exit 5
fi

# Copy rotatedisplays (unchanged)
if [ -r $DIR/rotatedisplays ]; then
    echo "Copying rotatedisplays."
    cp -f $DIR/rotatedisplays /usr/bin/ && chown root:root /usr/bin/rotatedisplays && chmod 0755 /usr/bin/rotatedisplays
fi

systemctl daemon-reload
systemctl enable displaycameras

echo "Installation Successful!"
echo "Start X11 first: sudo systemctl start xorg"
echo "Then start cameras: sudo systemctl start displaycameras"
exit 0
