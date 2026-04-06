#!/bin/bash

DISPLAY_NUM=:0
RESOLUTION="1920x1080x24"
VNC_PORT=5900
NOVNC_PORT=6080

echo "==> Starting Xvnc (TigerVNC) at $DISPLAY_NUM ($RESOLUTION)"
Xvnc $DISPLAY_NUM \
    -geometry 1920x1080 \
    -depth 24 \
    -rfbport $VNC_PORT \
    -SecurityTypes None \
    -ac &
sleep 3

echo "==> Starting Openbox window manager"
DISPLAY=$DISPLAY_NUM openbox-session &
sleep 2

echo "==> Starting noVNC on port $NOVNC_PORT"
websockify --web /usr/share/novnc $NOVNC_PORT localhost:$VNC_PORT &
sleep 2

echo ""
echo "============================================"
echo "  Display available at:"
echo "  http://localhost:$NOVNC_PORT/vnc.html"
echo "============================================"
echo ""

echo "==> Starting cron (repair job)"
cron

export DISPLAY=$DISPLAY_NUM

# Run tests if requested
if [ "$1" = "test" ]; then
    echo "==> Running automated tests"
    bash /tests/run_tests.sh
    exit $?
fi

# Otherwise drop to shell
exec bash
