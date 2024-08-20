# Debian Daily Driver
Initialize distro, patch configurations, basic security setup

Distribution: Debian

### 0. VM Settings
#### 0.1 VMware Fusion
**Networking**
- Bridged (WiFi or LAN) - issue with IPv6 for Auto

**Display**
- Use full resolution for Retina display
- Single Window: Stretch the virtual machine in the window
- Full Screen: Resize the virtual machine to fit the screen
#### 0.2 VMware Workstation
**Networking**
- Bridged (WiFi or LAN) - issue with IPv6 for Auto

**Display**
- Use full resolution for Retina display
- Single Window: Stretch the virtual machine in the window
- Full Screen: Resize the virtual machine to fit the screen

### 1. Installation
- Install without DE
- Install packages using repo/mirror
- Language: US
- Locale: US or US (macintosh)
- Timezone: Berlin

### 2. Initial Setup

**Step 0 - Elevate privieleges to root**

**Step 1 - Fix /etc/apt/sources.list**

Remove or comment out the following line from `/etc/apt/sources.list` referencing the ISO as a source.
```
deb cdrom:[Debian GNU/Linux 12.6.0 _Bookworm_ - Official arm64 DVD Binary-1 with firmware 20240629-10:19]/ bookworm contrib main non-free-firmware
```
**Step 2 - Verify package management**

First check basic networking using an apt source.
```bash
nslookup deb.debian.org
ping -4 -c 5 deb.debian.org
ping -6 -c 5 deb.debian.org
```
Then check whether apt is able to resolve those sources.
```shell
apt-get update
```
**Step 3 - Install further sources**
```bash
# firefox

# vscode
wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | tee /etc/apt/sources.list.d/vscode.list > /dev/null
rm -f packages.microsoft.gpg

apt-get update
```
**Step 4 - Install Software**
```bash
apt-get update
# some basic tools
apt-get install wget gpg curl git
# network
apt-get install systemd-resolved
# desktop environment
apt-get install xorg i3 kitty
# shell
apt-get install zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
# security
apt-get install sudo
# some common tools
apt-get install nmap
# basic user applications
apt-get install firefox code
```
**Step 5 - Initialize Desktop Environment**
```bash
update-alternatives --set x-terminal-emulator kitty
```
**Step 6 - s**
