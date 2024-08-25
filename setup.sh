#!/bin/bash

# ==============================================================================
# Author: Julijan Nedic
#
# Description:
# Automation script to perform the setup steps 
# described in README.
# ==============================================================================

USER="$1"
STAGE="$2"
SOURCES="/etc/apt/sources.list"

#
# Logging
#
LOG="%s\n\n\n%s\n\n\n%s"

VERIFICATION_LOG=$(cat << EOM
# ==============================================================
# Verification Log
# ==============================================================\n
EOM
)

INSTALL_LOG=$(cat << EOM
# ==============================================================
# Package Installation Log
# ==============================================================\n
EOM
)
INSTALL_MSG_SUCC="\n[+] Sucessfully installed package %s"
INSTALL_MSG_FAIL="\n[-] Failed to install package %s"

COMPONENT_LOG=$(cat << EOM
# ==============================================================
# Component Log
# ==============================================================\n
EOM
)
COMPONENT_MSG_SECTION="\n#\n# %s\n#\n"
COMPONENT_MSG_FAIL_INSTALL="\n[-] Failed to pull necessary packages to \
    initialize %s"
COMPONENT_MSG_SUCC="\n[+] Successfully initialized %s"

#
# Packages
#
PKG_DE=("xorg" "i3" "kitty")
PKG_SHELL=("zsh")
PKG_SECURITY=("sudo")
PKG_NETWORK=("systemd-resolved")
PKG_APP=("firefox-esr" "code")
PKG_TOOL=("nmap")

NIX_DIRS=(
        ["/home/$USER/git/kernels"]="nix/kernel-dev.shell.nix"
)


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
        if ! \
            which "$pkg" > /dev/null 2>&1 || \
            dpkg -s "$pkg" > /dev/null 2>&1 \
        ; then
                result=1
        fi
        return result
}

_clone_repo()
{
        result=0
        repo="$1"
        branch="$2"
        dir="$3"
        if [ -d $dir ]; then
                git clone -b $branch $repo $dir
                result=$?
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
                apt-get install $pkg > /dev/null 2>&1
                if _verify_package $pkg; then
                        INSTALL_LOG+=$(printf "$INSTALL_MSG_SUCC" "$pkg")
                else
                        INSTALL_LOG+=$(printf "$INSTALL_MSG_FAIL" "$pkg")
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
# Verify base installation
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
        for url in "${srcUrls[@]}"; do
                domain=$(printf "$url" | \
                    sed -e 's/[^/]*\/\/\([^@]*@\)\?\([^:/]*\).*/\2/')
                if nslookup $domain > /dev/null 2>&1; then
                        if ! \
                                ping -4 -c 5 "$domain" > /dev/null 2>&1 && \
                                ping -6 -c 5 "$domain" > /dev/null 2>&1 \
                        ; then
                                result=1
                        fi
                else
                        result=1
                fi
        done
        return $result
}

verify()
{
        result=0
        if ! \
            verify_sources && \
            verify_network \
        ; then
                result=1
        fi
        return result
}

# ==============================================================================
# Initialize components (install, setup, configs)
# ==============================================================================

_init_pkgmgmt_sources()
{
        # add microsoft pki and sources (vscode)
        # https://code.visualstudio.com/docs/setup/linux
        wget -qO- https://packages.microsoft.com/keys/microsoft.asc | \
                gpg --dearmor > packages.microsoft.gpg
        install -D -o root -g root -m 644 packages.microsoft.gpg \ 
                /etc/apt/keyrings/packages.microsoft.gpg
        echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings\
            /packages.microsoft.gpg] https://packages.microsoft.com/\
                repos/code stable main" | \
                    tee /etc/apt/sources.list.d/vscode.list > /dev/null
        rm -f packages.microsoft.gpg
}

_init_pkgmgmt_nix()
{
        result=0
        # set up nix package manager
        sh <(curl -L https://nixos.org/nix/install) --daemon
        if _verify_package "nix"; then
                COMPONENT_LOG+=$(printf "$COMPONENT_MSG_SUCC" "nix")
        else
                COMPONENT_LOG+=$(printf "$COMPONENT_MSG_FAIL_INSTALL" "nix")
                result=1
        fi
}

#
# Edit pki, sources and set up nix
#
init_pkgmgmt()
{
        result=0
        if ! \
                _init_pkgmgmt_sources && \
                _init_pkgmgmt_nix \
        ; then
                result=1
        fi
        return result
}

init_de()
{
        result=0
        if _install_packages "${PKG_DE[@]}"; then
                update-alternatives --set x-terminal-emulator kitty
                COMPONENT_LOG+=$(printf "$COMPONENT_MSG_SUCC" "DE")
        else
                COMPONENT_LOG+=$(printf "$COMPONENT_MSG_FAIL_INSTALL" "DE")
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
                sh -c "$(curl -fsSL https://raw.githubusercontent.com/\
                    ohmyzsh/ohmyzsh/master/tools/install.sh)"
        else
                COMPONENT_LOG+=$(printf "$COMPONENT_MSG_FAIL_INSTALL" "SHELL")
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
                COMPONENT_LOG+=$(printf "$COMPONENT_MSG_FAIL_INSTALL" "sudo")
                result=1
        fi
        return result
}

_init_security_auditd()
{
        result=0
        if _install_packages "auditd"; then
                service auditd start
                systemctl enable auditd                
        else
                COMPONENT_LOG+=$(printf "$COMPONENT_MSG_FAIL_INSTALL" "auditd")
                result=1
        fi
        return result
}

init_security()
{
        result=0
        COMPONENT_LOG+=$(printf "$COMPONENT_MSG_SECTION" "SECURITY")
        if ! \
            _init_security_sudo && \
            _init_security_auditd && \
            _init_security_selinux \
        ; then
                result=1
        fi
        return result
}

_init_configs_nix()
{
        result=0
        for dir in "${!NIX_DIRS[@]}"; do
                if ! [ -d "$dir" ]; then
                        mkdir -p "$dir"
                        cp "${NIX_DIRS[$dir]}" "$dir/shell.nix"
                fi
                if ! [ -d "$dir" && -f "$dir/shell.nix"]; then
                        result=1
                fi
        done
        return result
}

_init_configs_patch()
{
        result=0
        for file in configs/; do
                target=$(awk 'NR==1 {print; exit}' "$file")
                if [[ "$file" =~ ^*.patch ]]; then
                        patch "$target" < "$file"
                elif [[ "$file" =~ ^*.append ]]
                        cat "$file" | tee -a "$target"
                else
                        :
                fi
        done
        return result
}

#
# Apply pre-defined patches to configuration files
#
init_configs()
{
        result=0
        # create i3 config
        cp /etc/i3/config ~/.config/i3/config
        if ! \
            _init_configs_patch && \
            _init_configs_nix \
        ; then
                result=1
        fi
        return result
}

#
# Set up systemd networking, requires reboot
#
init_network()
{
        result=0
        if _install_packages "${PKG_NETWORK[@]}"; then
                systemctl start systemd-resolved.service
                systemctl enable systemd-resolved.service
                if ! systemctl status systemd-resolved.service > \
                    /dev/null 2>&1; then
                        result=1
                fi
        else
                COMPONENT_LOG+=$(printf "$COMPONENT_MSG_FAIL_INSTALL" "NETWORK")
                result=1
        fi
        return result
}

init()
{
        result=0
        if ! \
            init_pkgmgmt && \
            init_de && \
            init_shell && \
            init_security "$USER" && \
            init_configs && \
            # install further apps and tools
            _install_packages "${PKG_APP[@]}" && \
            _install_packages "${PKG_TOOL[@]}" && \
            init_network \
        ; then
                result=1
        fi
        return result
}

# ==============================================================================
# Build dev environments
# ==============================================================================

_build_dev_kernel()
{
        result=0
        dir_kernel="/home/$USER/git/kernels"
        git_kernel="git://git.kernel.org/pub/scm/linux/kernel/git/gregkh/staging.git"
        git_kernel_branch="staging-testing"
        if [ -d $dir_kernel ]; then
                git clone -b $git_kernel_branch $git_kernel $dir_kernel
                result=$?
        fi
        return result  
}

build_dev()
{
        result=0
        if ! _build_dev_kernel; then
                result=1
        fi
        return result
}

# ==============================================================================

core()
{
        result=0
        if verify && _install_packages "wget" "gpg" "curl" "git"; then
                init
                result=$?
        else
                result=1
        fi
        return result
}

post()
{
        
}

main()
{
        result=0
        if [[ "$STAGE" == "core" ]]; then
                core
                result=$?
        elif [[ "$STAGE" == "post" ]]; then
                post
                result=$?
        else
                echo "[-] Invalid stage argument, needs to be either \
                'core' or 'post'"
                result=1
        fi
        return result
}

main
return $?