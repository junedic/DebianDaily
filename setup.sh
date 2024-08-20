#!/bin/bash

# ==============================================================================
# Author: Julijan Nedic
#
# Description:
# Automation script to perform the setup steps 
# described in README.
# ==============================================================================

USER="debian"
SOURCES="/etc/apt/sources.list"

#
# Logging
#
LOG="%s\n\n\n%s\n\n\n%s"

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
INSTALL_MSG_SUCC="\n[+] Sucessfully installed package "
INSTALL_MSG_FAIL="\n[-] Failed to install package "


COMPONENT_LOG=$(cat << EOM
# ==============================================================
# Component Log
# ==============================================================\n
EOM
)
COMPONENT_MSG_FAIL_INSTALL="\n[-] Failed to pull necessary packages to \
    initialize %s"
COMPONENT_MSG_SUCC="\n[+] Successfully initialized %s"

#
# Packages
#
PKG_DE=("x-org" "i3" "kitty")
PKG_SHELL=("zsh")
PKG_SECURITY=("sudo")
PKG_NETWORK=("systemd-resolved")
PKG_APP=("firefox-esr" "code")
PKG_TOOL=("nmap")

# ==============================================================================
# Helper functions
# ==============================================================================

#
# Verify if a package has been installed
#
_verify_package()
{
    result=0
    pkg="$1"
    if which "$pkg" > /dev/null 2>&1 || dpkg -s "$pkg" > /dev/null 2>&1; then
        :
    else
        result=1
    fi
    return result
}

#
# Apt install a package and verify installation
#
_install_packages()
{
    packages="$@"       # combine arguments into array
    result=0            # inform about failed installation without aborting
	apt-get update
	for pkg in $packages; do
		apt-get install $pkg
        if _verify_package $pkg; then
            INSTALL_LOG+="$INSTALL_MSG_SUCC $pkg"
        else
            INSTALL_LOG+="$INSTALL_MSG_FAIL $pkg"
            result=1
        fi
	done
    return result
}

#
# Regex a file and comment out matching lines
#
_comment_out_line()
{
    result=0
    file="$1"
    regex="$2"
    # entire command as string, otherwise error prone
    awk_check="awk '$regex {\$0 = \"#\" \$0} {print}' $file"
    commented=$(eval $awk_check)
    echo "$commented" > "$file"
    return result
}

# ==============================================================================
# Verify installation
# ==============================================================================

#
# Verify and fix sources.list
#
verify_sources()
{
    result=0
    sources=$SOURCES
    regex_invalid_cdrom="(\$1 ~ /^deb/ && \$2 ~ /cdrom/)"   # check for iso
    regex_valid=""  # check if any valid sources exist
    if [ -f "$sources" ]; then
    # remove cdrom source, to fix apt error (VM)
        _comment_out_line "$sources" "$regex_invalid_cdrom"
    else
        result=1
    fi
    return result
}

#
# Verify basic networking for package installation
#
verify_network()
{
    result=0
    sources=$SOURCES
    # extract source urls
    srcUrls=($(awk '{ if ($1 ~ /deb/ && $2 ~ /http:*/) print $2 }' \ 
        /etc/apt/sources.list))
    # filter unique urls
    srcUrls=($(printf '%s\n' "${srcUrls[@]}" | sort -u))
    for url in $srcUrls; do
        # extract domain from url
        domain=$(printf "$url" | sed -e 's/[^/]*\/\/\([^@]*@\)\?\([^:/]*\).*/\2/')
        if ! nslookup $domain > /dev/null 2>&1; then    # check dns resolution
            result=1
            if ! ping -c 5 $domain > /dev/null 2>&1; then   # check reachability
                result=1
            fi
        fi
    done
    return result
}

# ==============================================================================
# Initialize components (install, setup, configs)
# ==============================================================================

#
# Edit pki, sources and set up nix
#
init_pkgmgmt()
{
    result=0
    # add microsoft pki and sources (vscode)
	wget -qO- https://packages.microsoft.com/keys/microsoft.asc | \
        gpg --dearmor > packages.microsoft.gpg
	install -D -o root -g root -m 644 packages.microsoft.gpg \ 
        /etc/apt/keyrings/packages.microsoft.gpg
	echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings\
        /packages.microsoft.gpg] https://packages.microsoft.com/\
            repos/code stable main" | \
                tee /etc/apt/sources.list.d/vscode.list > /dev/null
	rm -f packages.microsoft.gpg
    # set up nix package manager
    sh <(curl -L https://nixos.org/nix/install) --daemon
    return result
}

init_de()
{
    result=0
    if _install_packages "${PKG_DE[@]}"; then
        update-alternatives --set x-terminal-emulator kitty
        COMPONENT_LOG+=$(printf "$COMPONENT_MSG_SUCC" "DE")
    else
        COMPONENT_LOG+="$COMPONENT_MSG_FAIL_INSTALL DE"
        result=1
    fi
    return result
}

init_shell()
{
    result=0
    if _install_packages "${PKG_SHELL[@]}"; then
	    command -v zsh | tee -a /etc/shells
	    # create .zshrc config and install ohmyzsh
	    touch ~/.zshrc
	    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/\
            master/tools/install.sh)"
    else
        COMPONENT_LOG+="$COMPONENT_MSG_FAIL_INSTALL SHELL"
        result=1
    fi
    return result
}

_init_security_sudo()
{
    result=0
    user="$USER"
    # Install and initialize sudo
    if _install_packages "sudo"; then
        adduser "$user" sudo
    else
        COMPONENT_LOG+="$COMPONENT_MSG_FAIL_INSTALL SUDO"
        result=1
    fi
    return result
}

init_security()
{
    result=0
    if ! (
        _init_security_sudo || \
        _init_security_selinux || \
        _init_security_xx
    ); then
        result=1
    fi
    return result
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

# ==============================================================================

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