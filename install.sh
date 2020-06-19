#!/bin/bash
# Run as root to install the displaycameras package for streaming video feeds.
# Systemd init system is presumed.  If installing on 'nix with other init
# systems, you will have to edit this script or enable the displaycameras
# service with available tools for your init system.  The main script,
# normally installed at /usr/bin/displaycameras has an LSB header and will run
# as a systemv init script (if copied to /etc/init.d/).  No other init systems
# have been tested.

# What is the path to the installer?
DIR=`dirname "$(readlink -f "$0")"`

# Ensure prerequisites are installed.

for package in omxplayer fbi
do
if [ "`dpkg-query -s $package | grep Status | awk -v N=4 '{print $4}'`" != "installed" ]; then
	apt-get install $package -y
fi
done

# Put the files in place and set ownership and permissions.

if [ -r $DIR/displaycameras ]; then
	echo "Copying the main script and setting permissions."
	cp -f $DIR/displaycameras /usr/bin/ && chown root:root /usr/bin/displaycameras && chmod 0755 /usr/bin/displaycameras
else
	echo "The displaycameras file is missing or unreadable. This is a critical file."
	echo "Verify package contents."
	exit 1
fi
if [ -r $DIR/displaycameras.service ]; then
	echo "Copying the systemd init file and setting permissions."
	cp -f $DIR/displaycameras.service /etc/systemd/system/ && chown root:root /etc/systemd/system/displaycameras.service && chmod 0644 /etc/systemd/system/displaycameras.service
else
	echo "The displaycameras.service file is missing or unreadable. This is a critical file."
	echo "Verify package contents."
	exit 2
fi
# Config files, cron job, gpu memory split, and disable overscan support only if not upgrading
if [ "$1" != "upgrade" ]; then
	if [ -r $DIR/displaycameras.conf ]; then
		if [ -r /etc/displaycameras/displaycameras.conf ]; then
			[ -d /etc/displaycameras/bak ] || mkdir /etc/displaycameras/bak
			for i in `find /etc/displaycameras/ -maxdepth 1 -type f`; do
				mv -f $i /etc/displaycameras/bak/
			done
			echo "Your config files were backed up to /etc/displaycameras/bak"
		fi
		echo "Copying the global and layout configuration files."
		[ -d /etc/displaycameras ] || mkdir /etc/displaycameras
		cp -f $DIR/layout.conf.default /etc/displaycameras/ && chown root:root /etc/displaycameras/layout.conf.default && chmod 0644 /etc/displaycameras/layout.conf.default
		cp -f $DIR/displaycameras.conf /etc/displaycameras/ && chown root:root /etc/displaycameras/displaycameras.conf && chmod 0644 /etc/displaycameras/displaycameras.conf
	else
		echo "The displaycameras.conf file is missing or unreadable. This is a critical file."
		echo "Verify package contents."
		exit 3
	fi
	if [ -r $DIR/repaircameras.cron ]; then
		echo "Copying the repaircameras cron job and reloading cron."
		cp -f $DIR/repaircameras.cron /etc/cron.d/repaircameras && chown root:root /etc/cron.d/repaircameras && chmod 0755 /etc/cron.d/repaircameras
		systemctl restart cron
	else
		echo "The repaircameras.cron file is missing or unreadable. This is a critical file."
		echo "Verify package contents."
		exit 4
	fi
	# Set a reasonable GPU memory allocation
	# Determine total physical memory
	# System Memory
	sysmem="`free -m | grep Mem: | awk '$1=$1' | cut -f 2 -d " "`"
	# GPU Memory
	gpumem="`sudo raspi-config nonint get_config_var gpu_mem /boot/config.txt`"
	# Total Mem
	physmem=$((gpumem + sysmem))
	if [ "$physmem" -lt "500" ]; then
		split=96
		else
		if [ "$physmem" -lt "1000" ]; then
			split=192
			else
			split=256
		fi
	fi
	# Ask whether there's a custom split desired
	echo -n "Enter a custom gpu split if desired [gpu memory in MB] or [Enter] to use recommended split"
	read
	if [ "$REPLY" != "" ]; then
		if [ "$REPLY" -ge "64" -a "$REPLY" -le "512" ]; then
			split="$REPLY"
		fi
	fi
	# Set the split
	if [ "`raspi-config nonint get_config_var gpu_mem /boot/config.txt`" -lt "$split" ]; then
		echo "Setting gpu_mem allocation to "$split"MB"
		raspi-config nonint do_memory_split "$split"
	fi
	# Disable overscan support so that display resolution autodetection works
	if [ "`raspi-config nonint get_overscan`" = "0" ]; then
		echo "Disabling display overscan compensation. Set your monitor not to overscan."
		raspi-config nonint do_overscan 1
	fi
fi
if [ -r $DIR/omxplayer_dbuscontrol ]; then
	echo "Copying the omxplayer control script."
	cp -f $DIR/omxplayer_dbuscontrol /usr/bin/ && chown root:root /usr/bin/omxplayer_dbuscontrol && chmod 0755 /usr/bin/omxplayer_dbuscontrol
else
	echo "The omxplayer_dbuscontrl file is missing or unreadable. This is a critical file."
	echo "Verify package contents."
	exit 5
fi
if [ -r $DIR/rotatedisplays ]; then
	echo "Copying the display rotating script and setting permissions."
	cp -f $DIR/rotatedisplays /usr/bin/ && chown root:root /usr/bin/rotatedisplays && chmod 0755 /usr/bin/rotatedisplays
else
	echo "The rotatedisplays file is missing or unreadable. This file is required to support display rotation."
	echo "Verify package contents."
fi
if [ -r $DIR/black.png ]; then
	echo "Copying the black background file and setting ownership."
	cp -f $DIR/black.png /usr/bin/ && chown root:root /usr/bin/black.png
else
	echo "The black.png file is missing or unreadable. Screen blanking will not work"
	echo "with out it.  Verify package contents."
fi

# Update systemd and enable the displaycameras service.
systemctl daemon-reload
systemctl enable displaycameras

echo "Installation Successful!"
read -p "See the README.md? [Y/y/N/n]"
if [ "$REPLY" = "Y" -o "$REPLY" = "y" ]; then
	echo "Use the space bar (or PgDn) to page down, PgUp to page up, q to quit"
	read -p "Press Enter to begin."
	less $DIR/README.md
fi
exit 0
