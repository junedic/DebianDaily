#!/bin/bash

# ==============================================================
# Author: Julijan Nedic
#
# Description:
#
# ==============================================================

# ==============================================================
# Helper functions
# ==============================================================

_verify_package()
{
    
}

_install_packages()
{
    packages="$@"
	apt-get update
	for pkg in $packages; do
		apt-get install $pkg
	done
}

_comment_out_line()
{
    file="$1"
    regex="$2"
    awk_check="awk '$regex {\$0 = \"#\" \$0} {print}' $file"
    commented=$(eval $awk_check)
    echo "$commented" > "$file"
}

# ==============================================================
# Verify installation
# ==============================================================

verify_sources()
{
    sources="/etc/apt/sources.list"
    regex_invalid_cdrom="(\$1 ~ /^deb/ && \$2 ~ /cdrom/)"
    regex_valid=""
    if [ -f "$sources" ]; then
        _comment_out_line "$sources" "$regex_invalid_cdrom"
    else
        return 0
    fi
}

verify_network()
{

}

# ==============================================================
# Initialize components
# ==============================================================

init_sources()
{
	# firefox
	
	# vscode
	wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
	install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
	echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | tee /etc/apt/sources.list.d/vscode.list > /dev/null
	rm -f packages.microsoft.gpg
}

init_de()
{
    _install_packages "x-org" "i3" "kitty"
	update-alternatives --set x-terminal-emulator kitty
}

init_shell()
{
    _install_packages "zsh"
	command -v zsh | tee -a /etc/shells
	# create .zshrc config and install ohmyzsh
	touch ~/.zshrc
	sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
}

init_security()
{
    # install and initialize sudo
    user="$1"
    _install_packages "sudo"
	adduser "$user" sudo
	# install and initialize
}

init_configs()
{
    # create i3 config
	cp /etc/i3/config ~/.config/i3/config
    # update configuration files
    for file in configs/; do
        if [[ "$file" =~ ^*.patch  ]]
            patch 
        elif [[ "$file" =~ ^*.append ]]
            tee
        fi
    done
}

# ==============================================================

main()
{
    user="$1"
    if ! verify_sources; then
        echo
    fi
    _install_packages "wget" "gpg" "curl" "git"
    init_sources
    init_de
    init_shell
    init_security "$user"
    init_configs
    # install further apps and tools
    apps=(
        "firefox-esr"
        "code"
    )
    tools=(
        "nmap"
    )
    _install_packages "${apps[@]}"
    _install_packages "${tools[@]}"
}

main