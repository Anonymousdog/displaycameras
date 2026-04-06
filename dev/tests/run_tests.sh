#!/bin/bash
# Automated test suite for displaycameras mpv rewrite
# Run inside the Docker container

PASS=0
FAIL=0
LOGDIR=/var/log/displaycameras
TESTLOG=$LOGDIR/test-results.log
mkdir -p $LOGDIR

# Tee all output to test log
exec > >(tee -a "$TESTLOG") 2>&1

echo "================================================"
echo "  displaycameras mpv rewrite — test run"
echo "  $(date '+%Y-%m-%d %H:%M:%S')"
echo "  Logs: $LOGDIR"
echo "================================================"

ok()      { echo "  [PASS] $1"; PASS=$((PASS+1)); }
fail()    { echo "  [FAIL] $1"; FAIL=$((FAIL+1)); }
section() { echo ""; echo "=== $1 ==="; }

# ─────────────────────────────────────────
section "1. Prerequisites"
# ─────────────────────────────────────────

which mpv &>/dev/null          && ok "mpv installed"          || fail "mpv not found"
which socat &>/dev/null        && ok "socat installed"        || fail "socat not found"
which wmctrl &>/dev/null       && ok "wmctrl installed"       || fail "wmctrl not found"
which xset &>/dev/null         && ok "xset installed"         || fail "xset not found"
which mpv_ipccontrol &>/dev/null && ok "mpv_ipccontrol found" || fail "mpv_ipccontrol not found"
which displaycameras &>/dev/null && ok "displaycameras found" || fail "displaycameras not found"
[ -f /etc/displaycameras/displaycameras.conf ] && ok "displaycameras.conf exists" || fail "displaycameras.conf missing"
[ -f /etc/displaycameras/layout.conf.default ] && ok "layout.conf.default exists" || fail "layout.conf.default missing"
[ -f /test/test.mp4 ]          && ok "test video exists"      || fail "test video missing"

# ─────────────────────────────────────────
section "2. Geometry Conversion"
# ─────────────────────────────────────────

convert_geometry() {
    read x1 y1 x2 y2 <<< $1
    echo "$((x2-x1+1))x$((y2-y1+1))+${x1}+${y1}"
}

[ "$(convert_geometry '0 0 639 359')"      = "640x360+0+0"      ] && ok "Geometry: upper_left"   || fail "Geometry: upper_left"
[ "$(convert_geometry '640 0 1279 359')"   = "640x360+640+0"    ] && ok "Geometry: upper_middle" || fail "Geometry: upper_middle"
[ "$(convert_geometry '1280 0 1919 359')"  = "640x360+1280+0"   ] && ok "Geometry: upper_right"  || fail "Geometry: upper_right"
[ "$(convert_geometry '0 360 639 719')"    = "640x360+0+360"    ] && ok "Geometry: center_left"  || fail "Geometry: center_left"

# ─────────────────────────────────────────
section "3. displaycameras start/status/stop"
# ─────────────────────────────────────────

displaycameras start
sleep 2

[ -f /var/run/displaycameras/displaycameras.pid ] && ok "PID file created" || fail "PID file missing"

status_out=$(displaycameras status)
playing=$(echo "$status_out" | grep -c "is Playing")
[ "$playing" -ge 1 ] && ok "$playing camera(s) Playing" || fail "No cameras playing: $status_out"

displaycameras stop
sleep 2

pgrep mpv &>/dev/null && fail "mpv still running after stop" || ok "All mpv stopped after stop"
[ ! -f /var/run/displaycameras/displaycameras.pid ] && ok "PID file removed" || fail "PID file still exists"

# ─────────────────────────────────────────
section "3b. Optimization flags in mpv args"
# ─────────────────────────────────────────

displaycameras start
sleep 3

mpv_args=$(ps -o args= -C mpv | head -1)

echo "$mpv_args" | grep -q '\-\-no-cache'              && ok "Flag: --no-cache"              || fail "Flag: --no-cache missing"
echo "$mpv_args" | grep -q '\-\-demuxer-max-bytes'     && ok "Flag: --demuxer-max-bytes"     || fail "Flag: --demuxer-max-bytes missing"
echo "$mpv_args" | grep -q '\-\-scale=bilinear'        && ok "Flag: --scale=bilinear"        || fail "Flag: --scale=bilinear missing"
echo "$mpv_args" | grep -q '\-\-no-osc'                && ok "Flag: --no-osc"                || fail "Flag: --no-osc missing"
echo "$mpv_args" | grep -q '\-\-no-audio'              && ok "Flag: --no-audio"              || fail "Flag: --no-audio missing"
echo "$mpv_args" | grep -q '\-\-demuxer-lavf-probesize' && ok "Flag: --demuxer-lavf-probesize" || fail "Flag: --demuxer-lavf-probesize missing"
echo "$mpv_args" | grep -q '\-\-hwdec'                  && ok "Flag: --hwdec present"          || fail "Flag: --hwdec missing"

displaycameras stop
sleep 2

# ─────────────────────────────────────────
section "4. displaycameras repair"
# ─────────────────────────────────────────

displaycameras start
sleep 3

# Manually kill one camera to simulate failure
cam_pid=$(cat /var/run/displaycameras/mpv-cam1.pid 2>/dev/null)
if [ -n "$cam_pid" ]; then
    kill $cam_pid 2>/dev/null
    sleep 1
    kill -0 $cam_pid 2>/dev/null && fail "Camera not killed" || ok "Simulated camera failure (cam1)"
    displaycameras repair
    sleep 5
    new_status=$(mpv_ipccontrol cam1 getplaystatus)
    [ "$new_status" = "Playing" ] && ok "cam1 recovered after repair" || fail "cam1 not recovered: '$new_status'"
else
    fail "Could not get cam1 PID for repair test"
fi

displaycameras stop
sleep 2

# ─────────────────────────────────────────
section "5. systemd service lifecycle"
# ─────────────────────────────────────────

# Check systemd services are running
systemctl is-active xorg &>/dev/null     && ok "xorg.service active"     || fail "xorg.service not active"
systemctl is-active openbox &>/dev/null  && ok "openbox.service active"  || fail "openbox.service not active"
systemctl is-active novnc &>/dev/null    && ok "novnc.service active"    || fail "novnc.service not active"
systemctl is-active cron &>/dev/null     && ok "cron.service active"     || fail "cron.service not active"

# Test displaycameras via systemctl
systemctl start displaycameras
sleep 5
systemctl is-active displaycameras &>/dev/null && ok "displaycameras.service active" || fail "displaycameras.service not active"

status_out=$(displaycameras status)
playing=$(echo "$status_out" | grep -c "is Playing")
[ "$playing" -ge 1 ] && ok "systemctl start: $playing camera(s) Playing" || fail "systemctl start: no cameras playing"

# Test reload (triggers repair)
systemctl reload displaycameras
sleep 3
systemctl is-active displaycameras &>/dev/null && ok "service still active after reload" || fail "service died after reload"

# Test stop completes within TimeoutStopSec (30s)
timeout 35 systemctl stop displaycameras
[ $? -eq 0 ] && ok "systemctl stop completed within timeout" || fail "systemctl stop timed out"

systemctl is-active displaycameras &>/dev/null && fail "service still active after stop" || ok "service stopped"
pgrep mpv &>/dev/null && fail "mpv still running after systemctl stop" || ok "all mpv stopped after systemctl stop"

# ─────────────────────────────────────────
section "6. rotate / rotaterev"
# ─────────────────────────────────────────

SEQ_FILE=/tmp/displaycameras.seq

displaycameras start
sleep 3

[ -f "$SEQ_FILE" ] && ok "Sequence file exists" || fail "Sequence file missing"
[ "$(cat $SEQ_FILE)" = "0" ] && ok "Initial sequence is 0" || fail "Initial sequence: $(cat $SEQ_FILE)"

# Capture positions before rotate
before=$(DISPLAY=:0 wmctrl -l -G 2>/dev/null)

displaycameras rotate
sleep 1

[ "$(cat $SEQ_FILE)" = "3" ] && ok "Sequence after rotate: 3" || fail "Sequence after rotate: $(cat $SEQ_FILE) (expected 3)"

after=$(DISPLAY=:0 wmctrl -l -G 2>/dev/null)
[ "$before" != "$after" ] && ok "Windows moved after rotate" || fail "Windows unchanged after rotate"

displaycameras rotaterev
sleep 1

[ "$(cat $SEQ_FILE)" = "0" ] && ok "Sequence after rotaterev: 0" || fail "Sequence after rotaterev: $(cat $SEQ_FILE) (expected 0)"

returned=$(DISPLAY=:0 wmctrl -l -G 2>/dev/null)
[ "$before" = "$returned" ] && ok "Windows returned to original positions" || fail "Windows not back to original positions"

displaycameras stop
sleep 2

# rotate without running cameras should exit cleanly
displaycameras rotate 2>/dev/null
[ $? -eq 0 ] && ok "rotate without PIDFILE exits 0" || fail "rotate without PIDFILE failed"

err=$(displaycameras rotate 2>&1 >/dev/null)
[ -z "$err" ] && ok "rotate without PIDFILE no stderr" || fail "rotate without PIDFILE stderr: $err"

# ─────────────────────────────────────────
section "Summary"
# ─────────────────────────────────────────
echo ""
echo "  Passed: $PASS"
echo "  Failed: $FAIL"
echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "  ALL TESTS PASSED"
else
    echo "  SOME TESTS FAILED"
    echo ""
    echo "=== Log files for analysis ==="
    echo "  Test results : $TESTLOG"
    echo "  Main script  : $LOGDIR/displaycameras.log"
    echo "  IPC commands : $LOGDIR/ipc.log"
    for f in $LOGDIR/mpv-*.log; do
        echo "  mpv          : $f"
    done
    echo ""
    echo "=== Last 20 lines of displaycameras.log ==="
    tail -20 $LOGDIR/displaycameras.log 2>/dev/null || echo "  (empty)"
    echo ""
    echo "=== Last 20 lines of ipc.log ==="
    tail -20 $LOGDIR/ipc.log 2>/dev/null || echo "  (empty)"
fi

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
