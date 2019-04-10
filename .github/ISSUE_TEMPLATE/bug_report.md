---
name: Bug report
about: Create a report to help us improve

---

**_Before filing a bug report_**

**Replicate your issue on Raspbian Lite**
Raspbian Lite is the preferred target OS for this system.  I will not address bugs that can only be replicated on 'nix with a graphical user interface.

**Ensure your operating system is up-to-date**
...and that you can replicate the problem with an up-to-date (and rebooted) system.
To ensure all is update, run the following in a terminal, `sudo apt-get update && sudo apt-get dist-upgrade -y && sudo apt-get auto-remove -y && sudo apt-get autoclean`

_**If you do the above two things and can still replicate the issue, then...**_

**Describe the bug**
A clear and concise description of what the bug is.

**To Reproduce**
Steps to reproduce the behavior:
1. Install per README.md
2. Configure my feeds in layout.conf.default
3. Run 'sudo displaycameras start'
4. See error "..."

**Expected behavior**
A clear and concise description of what you expected to happen.

**Screenshots**
If applicable, add screenshots to help explain your problem.

**Raspberry Pi (please complete the following information):**
 - Hardware model
 - OS: [e.g. Raspbian_Lite Stretch]
 - Console: [X-session/Pixel vs Text Console]
 - gpu memory split: [e.g. 256MB]
 - displaycameras Version [e.g. 0.8.3.3]

**Display Configuration
 - Display/Monitor resolution: [e.g., 1920x1080]
 - Window matrix: [e.g. 2x2]
 - Feed resolution: [e.g., low-resolution or 640x360]

**Camera information (please complete the following information):**
 - Number of cameras: [e.g. 6]
 - Camera models (if not Ubiquiti):
 - Managed/Unmanaged

**Features enabled (please complete the following information):**
 - Rotation: [yes/no]
 - Display Blanking: [yes/no]
 - Display Detection: [yes/no]

**NVR information (please complete the following information):**
 - NVR hardware
 - NVR UniFi Video server version: [e.g., 3.9.7]

**Additional context**
Add any other context about the problem here.

**Files
Attach any suspect config files.
