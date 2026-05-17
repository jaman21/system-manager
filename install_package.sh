#!/bin/sh
set -e

PKG_MANAGER=""

detect_package_manager() {
	if [ -x "/usr/bin/pacman" ] && [ -f "/usr/bin/pacman" ]; then
		echo "pacman"
		return
	fi

	if [ -x "/usr/bin/apt-get" ] && [ -f "/usr/bin/apt-get" ]; then
		echo "apt-get"
		return
	fi

	if [ -x "/usr/bin/dnf" ] && [ -f "/usr/bin/dnf" ]; then
		echo "dnf"
		return
	fi

	if [ -x "/usr/bin/yum" ] && [ -f "/usr/bin/yum" ]; then
		echo "yum"
		return
	fi

	if [ -x "/usr/bin/zypper" ] && [ -f "/usr/bin/zypper" ]; then
		echo "zypper"
		return
	fi

	if [ -x "/usr/bin/eopkg" ] && [ -f "/usr/bin/eopkg" ]; then
		echo "eopkg"
		return
	fi

	echo "unknown package manager"
	exit
}

check_root() {
	if [ "$(id -u)" -eq 0 ]; then
		return 0
	else
		return 1
	fi
}

install_dependencies() {
	if command -v sudo >/dev/null 2>&1 &&
		command -v curl >/dev/null 2>&1 &&
		command -v unzip >/dev/null 2>&1 &&
		command -v bash >/dev/null 2>&1; then
		return 0
	fi
	case $PKG_MANAGER in
	"pacman")
		pacman -Sy
		pacman -S --noconfirm sudo
		sudo pacman -S --noconfirm curl unzip bash
		;;
	"apt-get")
		apt-get update
		apt-get install -y sudo
		sudo apt-get install -y curl unzip bash nautilus-admin
		;;
	"dnf")
		dnf install -y sudo
		enable_epel
		sudo dnf install -y curl unzip bash
		;;
	"yum")
		yum install -y sudo
		enable_epel
		sudo yum install -y curl unzip bash
		;;
	"zypper")
		zypper install -y sudo
		sudo zypper install -y curl unzip bash
		;;

	"eopkg")
		eopkg update-repo
		eopkg install -y sudo
		sudo eopkg install -y curl unzip bash
		;;
	esac
}

sync_system_time() {
	case $PKG_MANAGER in
	"pacman")
		sudo pacman -S --noconfirm chrony
		;;
	"apt-get")
		sudo apt-get install -y chrony
		;;
	"dnf")
		sudo dnf install -y chrony
		;;
	"yum")
		sudo yum install -y chrony
		;;
	"zypper")
		sudo zypper install -y chrony
		;;
	"eopkg")
		sudo eopkg install -y chrony
		;;
	esac

	if command -v systemctl >/dev/null 2>&1; then
		if sudo systemctl enable --now chronyd >/dev/null 2>&1 || sudo systemctl enable --now chrony >/dev/null 2>&1; then
			return 0
		fi
	elif command -v rc-service >/dev/null 2>&1; then
		if sudo rc-update add chronyd default >/dev/null 2>&1 || sudo rc-update add chrony default >/dev/null 2>&1; then
			sudo rc-service chronyd start >/dev/null 2>&1 || sudo rc-service chrony start >/dev/null 2>&1
			return 0
		fi
	fi

	echo "Warning: Failed to start chrony service"
	return 1
}

init_package_manager() {
	case $PKG_MANAGER in
	"pacman")
		sudo pacman -Sy
		;;
	"apt-get")
		sudo apt-get install -y gdebi synaptic
		;;
	"dnf")
		sudo dnf makecache --refresh -y
		;;
	"yum")
		sudo yum makecache -y
		;;
	"zypper")
		sudo zypper refresh
		;;

	"eopkg")
		sudo eopkg update-repo
		;;
	esac
}

configure_flatpak_env() {
	shell_config=""
	if [ -n "$BASH_VERSION" ] && [ -f "$HOME/.bashrc" ]; then
		shell_config="$HOME/.bashrc"
	elif [ -n "$ZSH_VERSION" ] && [ -f "$HOME/.zshrc" ]; then
		shell_config="$HOME/.zshrc"
	elif [ -f "$HOME/.profile" ]; then
		shell_config="$HOME/.profile"
	else
		shell_config="$HOME/.profile"
		touch "$shell_config"
	fi

	if check_root; then
		if ! echo "$XDG_DATA_DIRS" | grep -q '/var/lib/flatpak/exports/share'; then
			printf '%s\n' "export XDG_DATA_DIRS=\$XDG_DATA_DIRS:/var/lib/flatpak/exports/share:/root/.local/share/flatpak/exports/share" >>"$shell_config"
			export XDG_DATA_DIRS="$XDG_DATA_DIRS:/var/lib/flatpak/exports/share:/root/.local/share/flatpak/exports/share"
		fi
	else
		if ! echo "$XDG_DATA_DIRS" | grep -q '/var/lib/flatpak/exports/share'; then
			printf '%s\n' "export XDG_DATA_DIRS=\$XDG_DATA_DIRS:/var/lib/flatpak/exports/share:\$HOME/.local/share/flatpak/exports/share" >>"$shell_config"
			export XDG_DATA_DIRS="$XDG_DATA_DIRS:/var/lib/flatpak/exports/share:$HOME/.local/share/flatpak/exports/share"
		fi
	fi
}

install_flatpak() {
	# sync_system_time

	case $PKG_MANAGER in
	"pacman")
		sudo pacman -S --noconfirm flatpak fuse2
		;;
	"apt-get")
		sudo apt-get install -y flatpak
		if grep -q "ubuntu" /etc/os-release; then
			ubuntu_version=$(grep VERSION_ID /etc/os-release | cut -d'"' -f2)
			if [ "$(echo "$ubuntu_version" | cut -d'.' -f1)" -ge 24 ]; then
				# Ubuntu 24.04+
				sudo add-apt-repository universe -y
				sudo apt-get install -y libfuse2t64
			elif [ "$(echo "$ubuntu_version" | cut -d'.' -f1)" -ge 22 ]; then
				# Ubuntu 22.04+
				sudo add-apt-repository universe -y
				sudo apt-get install -y libfuse2
			else
				# Ubuntu 21.10 and below
				sudo apt-get install -y fuse libfuse2
			fi
			# sudo apt-get install -y software-properties-common
			# sudo add-apt-repository ppa:appimagelauncher-team/stable -y
			# sudo apt-get update
			# sudo apt-get install -y appimagelauncher
			if dpkg -l | grep -q appimagelauncher; then
				sudo apt-get remove -y appimagelauncher
				sudo add-apt-repository --remove ppa:appimagelauncher-team/stable -y
			fi
		else
			# Debian 等非 Ubuntu: 优先 libfuse2t64(新系统仓库), 无包或失败则 fuse + libfuse2
			sudo apt-get install -y libfuse2t64 || sudo apt-get install -y fuse libfuse2
		fi

		;;
	"dnf")
		sudo dnf install -y flatpak fuse fuse-libs
		;;
	"yum")
		sudo yum install -y flatpak
		# CentOS/RHEL needs to install fuse-sshfs from EPEL for FUSE support
		sudo yum --enablerepo=epel -y install fuse-sshfs
		;;
	"zypper")
		sudo zypper install -y flatpak fuse libfuse2
		;;

	"eopkg")
		sudo eopkg install -y flatpak fuse
		;;
	*)
		echo "Cannot install Flatpak, unsupported package manager"
		return 1
		;;
	esac

	if ! flatpak remote-list | grep -q "^flathub\b"; then
		flatpak remote-add --system --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo >/dev/null 2>&1 || flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
	fi
	flatpak remote-modify --system flathub --url=https://mirrors.ustc.edu.cn/flathub >/dev/null 2>&1 || flatpak remote-modify --user flathub --url=https://mirrors.ustc.edu.cn/flathub

	configure_flatpak_env

	flatpak update --appstream
	flatpak install -y io.github.prateekmedia.appimagepool
	flatpak install -y it.mijorus.gearlever
	if flatpak list | grep -q "com.github.ryonakano.pinit"; then
		flatpak uninstall -y flathub com.github.ryonakano.pinit
	fi
	flatpak install -y flathub com.github.dail8859.NotepadNext
}

main() {
	PKG_MANAGER=$(detect_package_manager)
	install_dependencies
	init_package_manager
	install_flatpak
}

main "$@"
