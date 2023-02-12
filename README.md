# !!!Warning!!!
As of Raspbian Bullseye release (as well as RPi4B), omxplayer and the hardware decoding that work hand-in-hand are deprecated and/or unsupported. In order to use displaycameras, you should install raspbian buster (lite preferred). If you use an RPi4B, your source video codec must have hardware decode support in the RPi4B gpu.
displaycameras *may* be rewritten around vlc, but challenges with vlc's DBUS support (for multiple vlc instances) may prevent the rewrite.
# Project Description
displaycameras is a set of scripts run as a service on RaspberryPi hardware to locally display RTSP streams from Ubiquiti security camera systems.  It uses omxplayer to perform hardware accelerated playback of each configured feed in a grid of "windows" into which you divide your display.  It uses omxplayer's integration with DBUS to perform monitored startup, watchdog, and repair functions on feeds in order to maximize predictable, reliable performance.  It will optionally auto-detect screen resolution (and apply customized configuration) in case RPis don't have reliably consistent displays (e.g., mobile use).  It is capable of displaying more feeds than there are visible windows in your display grid by rendering some feeds off screen and rotating feeds through window positions (on and off screen) in order to visibly display all feeds over a reasonable period of time.

## Donations
If you feel compelled to contribute to the project, feel free to send funds to https://www.paypal.me/anonymousdog

# Pre-requisites
* RaspberryPi hardware (for omxplayer)
* systemd init system (because Raspbian Lite is the intended target OS)
  * Raspian Lite is **STRONGLY** recommended.  Before filing bug reports, please ensure you can replicate the bug on Raspbian Lite.
  * If installing on 'nix with other init systems, you will have to edit the install script or enable the displaycameras service with available tools for your init system.
  * The main script, normally installed at /usr/bin/displaycameras has an LSB header and will run as a systemv init script (if copied to /etc/init.d/...maybe just symlink to the /usr/bin/ location [untested])?  No other init systems have been tested or are supported.

# Download/Install/Upgrade/Remove
## Download the Archive
### Latest Release (recommended)
Go to https://github.com/Anonymousdog/displaycameras/releases/latest and download the Source Code (tar.gz) file
### Latest Commits (only when directed)
Download https://github.com/Anonymousdog/displaycameras/archive/master.tar.gz

## Unpack the Archive
1. `tar -xvzf ./<source_code.tar.gz>`
2. `cd ./<source_code directory>` to move to the directory where the archive unpacked

## Make the Installer Executable
`chmod u+x ./install.sh`

## Installation
1. `sudo ./install.sh`
2. Accept the offer to view the README after successful installation and follow the instructions therein

## Upgrade
`sudo ./install.sh upgrade`

No changes will be made to your existing config files, cron job setup, gpu memory allocation, or hdmi overscan setup.

## Removal
1. Stop the service: `sudo systemctl stop displaycameras.service`
2. Disable the service: `sudo systemctl disable displaycameras.service`
3. Remove the files:
	a. Remove the config directory, `sudo rm -R /etc/displaycameras`
	b. Remove the service file, `sudo rm /etc/systemd/system/displaycameras.service`
	c. Remove the scripts, `sudo rm /usr/bin/omxplayer_dbuscontrol /usr/bin/black.png /usr/bin/rotatedisplays`
	d. Remove the crontab file, `sudo rm /etc/cron.d/repaircameras && sudo systemctl restart cron`
4. Remove the pre-requisites (optional): `for each package in omxplayer fbi; do sudo apt-get purge $package -y; done`
5. Remove pre-requisites' dependencies (optional): `sudo apt-get autoremove -y`

# CONFIGURATION
Remember to edit the /etc/displaycameras/displaycameras.conf and /etc/displaycameras/layout.conf.default files for your environment.

## Minimal Configuration

### Global Options
#### Main Conf File
Global options like screen blanking, omxplayer network timeout, startsleep, feedsleep, retry, displaydetect, and rotatedelay in /etc/displaycameras/displaycameras.conf.

All of these variables may be added to one or more layout configuration files to override the global options settings for one or more display layouts.

### Camera and Window Layout
* Screen/window matrix setup, window names, camera names, and camera feeds should be here (and most definitely NOT in the main config file).

!!!WARNING!!!

Camera Names must conform to DBUS namespace restrictions: valid UTF-8 only containing the ASCII characters "[A-Z][a-z][0-9]_" and must not begin with a digit or dot/period/"."

!!!WARNING!!!

* Global options (exept for displaydetect) in the main conf file may be overridden (for specific displays) by supplying their values in these files.
* Do NOT override 'displaydetect' settings in a layout config file; you will create problems.
#### Layout Conf Files
* All files in /etc/displaycameras/ which follow the naming convention 'layout.conf.<display resolution>' or the default layout conf file, layout.conf.default.
* Unless you enable display detection in the main config file, the system will always use the default layout conf file.
#### Default Layout Config File
The default layout file now has rotation disabled by default; so, it's safe to throw your camera names and feeds in there and just use it if you want an onscreen 2x2 matrix on reliably 1080p displays.  If you have more than four cameras, you'll want to uncomment the last line.

## TESTING
Test by starting the service manually, `sudo /usr/bin/displaycameras start`, to see the full output of the script.  In the main config file, /etc/displaycameras/displaycameras.conf, adjust feedsleep upward until you no longer see script output reflecting omxplayer playback (not startup) retries.

Once that is resolved, adjust startsleep upward until you no longer see script output reflecting omxplayer startup or playback retries.  Increase retries if results are inconsistent but you want short startup or feed sleep values (for quicker startup).

When you complete testing, clean up by stopping all test processes with `sudo /usr/bin/displaycameras stop`.

### Debugging
#### Verify omxplayer will play your feed RTSP URLs
To definitively rule out problems with omxplayer not playing your RTSP feeds, run the following in an SSH session:
`sudo omxplayer --no-keys --no-osd --avdict rtsp_transport:tcp <camera feed URL> --live -n -1 --timeout 30`
	
If your feed plays, there's a problem with your config for displaycameras.  If not, there's a problem with your URL or omxplayer won't play your feed.
#### Verify valid feed RTSP URLs
If that happens, you can verify the feed by trying to play it from VLC on the RPi or another device on the same network as the RPi.

If VLC plays it, you know the stream exists and that you have the correct URL.

## Managing the Service
The installer registers and activates the displaycameras service; so, it will start with the system (once networking and DBUS are running).

### Manual Service Management
#### Start
`sudo systemctl start displaycameras`
#### Stop
`sudo systemctl stop displaycameras`
#### Restart
`sudo systemctl restart displaycameras`
#### Systemd Status Display
`sudo systemctl status displaycameras`
#### Debugging Status Information
`sudo /usr/bin/displaycameras status` <-- this is not a call to systemd, just the script.

## Advanced Configurations
Perform all the steps in the minimal configuration and review the following options for tweaks to your setup.
### Display Detection
Enable display detection in displaycameras.conf and setup special layout configuration files for any display resolutions you want to support with auto-detection.  Use the 1440x900 or 1280x1028 (and other) files as examples, and duplicate the naming convention for these configuration file names, '/etc/displaycameras/layout.conf.<display resolution>' (e.g., /etc/displaycameras/layout.conf.1024x768). <--No, a 1024x768 layout config file is not included in this package.

#### Rotation
If you want to display more cameras on screen than the screen will hold, ensure you have at least as many windows defined as cameras, and uncomment the 'rotate="true"' line in the main config file (for all displays) or in a custom layout file (for a specific screen resolution).

##### Rotation stepping (new - alpha feature)
To rotate more aggressively than one feed at a time, set in the applicable layout.conf.* file "seq_step" to a integer between 1 and the number of cameras that fit on screen at any one time.

##### Screen "Flop" (new - alpha feature)
If you want rotation to show you a full screen of feeds, then show you as many as possible that were off screen, and so on until it goes back to the original set (i.e., "flopping" between unique screen-fulls of feeds), set "seq_step" equal to the number of cameras that fit on screen at one time.

#### Display Blanking
If your display shows background items from the terminal or GUI screen during rotation, you may want to enable screen "blanking" by uncommenting or adding a 'blank="true"' line in the main (for all displays) or custom layout files.

#### Proper feed resolutions
!!!WARNING!!!

Configure camera feeds that are the same resolution or SMALLER than your windows.  The RPi will struggle to downscale feeds to smaller windows.

#### Boot Config Changes
You may want to adjust the gpu_mem value in /boot/config.txt if gpu resources restrict performance.

Installation ensures there is a "disable_overscan=1" line in your /boot/config.txt file.  This disables overscan compensation which allows display resolutions autodetection to work properly.  We recommend you setup your monitor to disable overscan.  It is often enabled by default on televisions and some commercial displays.
