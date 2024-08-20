#!/bin/bash

# ==============================================================
# Author: Julijan Nedic
#
# Description:
# Automation script to perform the setup steps 
# described in README.
# ==============================================================

USER="debian"
SOURCES="/etc/apt/sources.list"

#
# Logging
#
VERIFICATION_LOG=$(cat << EOM
# ==============================================================
# Verification Log
# ==============================================================
EOM
)

INSTALL_LOG=$(cat << EOM
# ==============================================================
# Package Installation Log
# ==============================================================
EOM
)
INSTALL_MSG_SUCC="\n[X] Sucessfully installed package "
INSTALL_MSG_FAIL="\n[O] Failed to install package "


COMPONENT_LOG=$(cat << EOM
# ==============================================================
# Component Log
# ==============================================================
EOM
)
COMPONENT_MSG="\n#\n#%s\n#\n"
COMPONENT_MSG_INSTALL_FAIL=""

#
# Packages
#
PKG_DE=("x-org" "i3" "kitty")
PKG_SHELL=("zsh")
PKG_SECURITY=("sudo")
PKG_NETWORK=("systemd-resolved")
PKG_APP=("firefox-esr" "code")
PKG_TOOL=("nmap")

# ==============================================================
# Helper functions
# ==============================================================

#
# Verify if a package has been installed
#
_verify_package()
{
    pkg="$1"
    if which "$pkg" > /dev/null 2>&1 || dpkg -s "$pkg" > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

#
# Apt install a package and verify installation
#
_install_packages()
{
    packages="$@"       # combine arguments into array
    installFailure=0    # inform about failed installation without aborting
	apt-get update
	for pkg in $packages; do
		apt-get install $pkg
        if _verify_package $pkg; then
            INSTALL_LOG+="$INSTALL_MSG_SUCC $pkg"
        else
            INSTALL_LOG+="$INSTALL_MSG_FAIL $pkg"
            $installFailure=1
        fi
	done
    return $installFailure
}

#
# Regex a file and comment out matching lines
#
_comment_out_line()
{
    file="$1"
    regex="$2"
    # entire command as string, otherwise error prone
    awk_check="awk '$regex {\$0 = \"#\" \$0} {print}' $file"
    commented=$(eval $awk_check)
    echo "$commented" > "$file"
    return 0
}

# ==============================================================
# Verify installation
# ==============================================================

#
# Verify and fix sources.list
#
verify_sources()
{
    sources="/etc/apt/sources.list"
    regex_invalid_cdrom="(\$1 ~ /^deb/ && \$2 ~ /cdrom/)"   # check for iso as source
    regex_valid=""  # check if any valid sources exist
    if [ -f "$sources" ]; then
        # remove cdrom source, to fix apt error (VM)
        _comment_out_line "$sources" "$regex_invalid_cdrom"
    else
        return 1
    fi
    return 0
}

#
# Verify basic networking for package installation
#
verify_network()
{
    sources="/etc/apt/sources.list"
    # extract source urls
    srcUrls=($(awk '{ if ($1 ~ /deb/ && $2 ~ /http:*/) print $2 }' /etc/apt/sources.list))
    # filter unique urls
    srcUrls=($(printf '%s\n' "${srcUrls[@]}" | sort -u))
    for url in $srcUrls; do
        # extract domain from url
        domain=$(printf "$url" | sed -e 's/[^/]*\/\/\([^@]*@\)\?\([^:/]*\).*/\2/')
        if ! nslookup $domain > /dev/null 2>&1; then    # check dns resolution
            return 1
            if ! ping -c 5 $domain > /dev/null 2>&1; then   # check reachability
                return 1
            fi
        fi
    done
    return 0
}

# ==============================================================
# Initialize components (install, setup, configs)
# ==============================================================

#
# Edit pki and sources for external software to be installed
#
init_sources()
{
    # vscode
	wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
	install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
	echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | tee /etc/apt/sources.list.d/vscode.list > /dev/null
	rm -f packages.microsoft.gpg
    return 0
}

init_de()
{
    if ! _install_packages "${PKG_DE[@]}"; then
        return 1
    fi
    update-alternatives --set x-terminal-emulator kitty
    return 0
}

init_shell()
{
    if ! _install_packages "${PKG_SHELL[@]}"; then
        return 1
    fi
	command -v zsh | tee -a /etc/shells
	# create .zshrc config and install ohmyzsh
	touch ~/.zshrc
	sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
}

init_security()
{
    # Install and initialize sudo
    user="$1"
    if ! _install_packages "${PKG_SECURITY[@]}"; then
        return 1
    fi
	adduser "$user" sudo
	# Install and initialize x
}

#
# Apply pre-defined patches to configuration files
#
init_configs()
{
    # create i3 config
	cp /etc/i3/config ~/.config/i3/config
    for file in configs/; do
        if [[ "$file" =~ ^*.patch  ]]
            patch 
        elif [[ "$file" =~ ^*.append ]]
            tee
        fi
    done
}

#
# Set up systemd networking, requires reboot
#
init_network()
{
    if ! _install_packages "${PKG_NETWORK[@]}"; then
        return 1
    fi
    systemctl start systemd-resolved.service
    systemctl enable systemd-resolved.service
    return 0
}

# ==============================================================

main()
{
    if ! verify_sources; then
        echo
    fi
    if ! _install_packages "wget" "gpg" "curl" "git"; then
        return 1
    fi
    init_sources
    init_de
    init_shell
    init_security "$USER"
    init_configs
    # install further apps and tools
    _install_packages "${PKG_APP[@]}"
    _install_packages "${PKG_TOOL[@]}"
    init_network
}

main