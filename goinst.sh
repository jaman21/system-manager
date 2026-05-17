#!/bin/bash
GO_VER="1.24.2"
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
function DETECT_ARCH() {
	local arch
	arch=$(uname -m)
	case "$arch" in
	x86_64 | amd64) echo "amd64" ;;
	aarch64 | arm64) echo "arm64" ;;
	*) echo "Unsupported architecture: ${arch}" && exit ;;
	esac
}

ARCH=$(DETECT_ARCH)

PACKAGE_LIST_UPDATED=false

INSTALL_PACKAGES() {
	local packages=("$@")
	local all_packages_installed=true

	for package in "${packages[@]}"; do
		if ! command -v "$package" >/dev/null 2>&1; then
			all_packages_installed=false
			break
		fi
	done

	if [ "$all_packages_installed" = true ]; then
		return 0
	fi

	if [ "$OS" = darwin ]; then
		if ! command -v brew >/dev/null 2>&1; then
			echo "Homebrew is required"
			/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || exit
		fi

		if [ "$PACKAGE_LIST_UPDATED" = false ]; then
			brew update >/dev/null 2>&1
			PACKAGE_LIST_UPDATED=true
		fi

		for package in "${packages[@]}"; do
			if ! command -v "$package" >/dev/null 2>&1; then
				brew install "$package" || exit
			fi
		done
	else
		if [ "$PACKAGE_LIST_UPDATED" = false ]; then
			if command -v pacman >/dev/null 2>&1; then
				sudo pacman -Sy >/dev/null 2>&1
			elif command -v apt >/dev/null 2>&1; then
				sudo apt update >/dev/null 2>&1
			elif command -v dnf >/dev/null 2>&1; then
				sudo dnf makecache >/dev/null 2>&1
			elif command -v yum >/dev/null 2>&1; then
				sudo yum makecache >/dev/null 2>&1
			elif command -v zypper >/dev/null 2>&1; then
				sudo zypper refresh >/dev/null 2>&1
			elif command -v apk >/dev/null 2>&1; then
				sudo apk update >/dev/null 2>&1
			elif command -v eopkg >/dev/null 2>&1; then
				sudo eopkg update-repo >/dev/null 2>&1
			else
				echo "No supported package manager found"
				exit
			fi
			PACKAGE_LIST_UPDATED=true
		fi

		if command -v pacman >/dev/null 2>&1; then
			sudo pacman -S --noconfirm "${packages[@]}"
		elif command -v apt >/dev/null 2>&1; then
			sudo apt install -y "${packages[@]}"
		elif command -v dnf >/dev/null 2>&1; then
			sudo dnf install -y "${packages[@]}" >/dev/null 2>&1
		elif command -v yum >/dev/null 2>&1; then
			sudo yum install -y "${packages[@]}" >/dev/null 2>&1
		elif command -v zypper >/dev/null 2>&1; then
			sudo zypper install --non-interactive "${packages[@]}"
		elif command -v apk >/dev/null 2>&1; then
			sudo apk add --no-cache "${packages[@]}"
		elif command -v eopkg >/dev/null 2>&1; then
			sudo eopkg install -y "${packages[@]}"
		else
			echo "No supported package manager found"
			exit
		fi
	fi
}

function UPDATE_SHELL_CONFIG() {
	local config_file=$1
	[ ! -f "$config_file" ] && echo "Configuration file does not exist" && exit

	local go_vars=("GOPATH" "go/bin" "GO111MODULE" "GOTOOLCHAIN" "GOCACHE" "GOPROXY" "GOSUMDB")

	for VAR in "${go_vars[@]}"; do
		if [ "$OS" = darwin ]; then
			sed -i '' "/export.*${VAR//\//\\\/}/d" "$config_file"
		else
			sed -i "/export.*${VAR//\//\\\/}/d" "$config_file"
		fi
	done

	if [[ "$config_file" =~ .*fish.* ]]; then
		cat >>"$config_file" <<EOF
set -x PATH \$PATH /usr/local/go/bin
set -x GOPATH /opt/gopath
set -x GO111MODULE auto
set -x GOTOOLCHAIN auto
set -x GOCACHE ~/.cache/go-build
set -x GOPROXY https://goproxy.cn,direct
set -x GOSUMDB sum.golang.google.cn
EOF
	else

		cat >>"$config_file" <<EOF
export PATH=\$PATH:/usr/local/go/bin
export GOPATH=/opt/gopath
export GO111MODULE=auto
export GOTOOLCHAIN=auto
export GOCACHE=~/.cache/go-build
export GOPROXY=https://goproxy.cn,direct
export GOSUMDB=sum.golang.google.cn
EOF
	fi

	# [[ ! "$config_file" =~ .*fish.* ]] && . "$config_file" 2>/dev/null
}

function UPDATE_ALL_SHELL_CONFIGS() {
	local current_shell
	current_shell=$(basename "$SHELL" 2>/dev/null || echo "bash")

	case "$current_shell" in
	"bash")
		if [ -f ~/.bashrc ]; then
			UPDATE_SHELL_CONFIG ~/.bashrc
			# shellcheck source=/dev/null
			source ~/.bashrc 2>/dev/null
		fi
		;;
	"zsh")
		if [ -f ~/.zshrc ]; then
			UPDATE_SHELL_CONFIG ~/.zshrc
			# shellcheck source=/dev/null
			source ~/.zshrc 2>/dev/null
		fi
		;;
	"fish")
		if [ -f ~/.config/fish/conf.d/go.fish ]; then
			UPDATE_SHELL_CONFIG ~/.config/fish/conf.d/go.fish
			# shellcheck source=/dev/null
			source ~/.config/fish/conf.d/go.fish 2>/dev/null
		fi
		;;
	"sh")
		if [ -f ~/.profile ]; then
			UPDATE_SHELL_CONFIG ~/.profile
			# shellcheck source=/dev/null
			source ~/.profile 2>/dev/null
		fi
		;;
	*)
		echo "Unsupported shell: $current_shell"
		exit
		;;
	esac

	if ! sudo mkdir -p /opt/gopath 2>/dev/null; then
		echo "Failed to create GOPATH directory"
		exit
	fi
	sudo chown -R "$(whoami)" /opt/gopath

	export GOPATH=/opt/gopath
	export GO111MODULE=auto
	export GOTOOLCHAIN=auto
	export GOCACHE=~/.cache/go-build
	export GOPROXY=https://goproxy.cn,direct
	export GOSUMDB=sum.golang.google.cn
}

function UNINSTALL_GO() {
	if [ "$OS" = darwin ]; then
		if command -v brew >/dev/null 2>&1; then
			brew uninstall go
		fi
		sudo rm -rf /usr/local/go /opt/homebrew/bin/go /opt/homebrew/opt/go
	else
		if command -v pacman >/dev/null 2>&1; then
			sudo pacman -Rs --noconfirm go >/dev/null 2>&1
		elif command -v apt >/dev/null 2>&1; then
			sudo apt purge -y golang golang-go >/dev/null 2>&1
			sudo apt autoremove -y >/dev/null 2>&1
		elif command -v dnf >/dev/null 2>&1; then
			sudo dnf remove -y golang >/dev/null 2>&1
		elif command -v yum >/dev/null 2>&1; then
			sudo yum remove -y golang >/dev/null 2>&1
		elif command -v zypper >/dev/null 2>&1; then
			sudo zypper remove -y go >/dev/null 2>&1
		elif command -v apk >/dev/null 2>&1; then
			sudo apk del go >/dev/null 2>&1
		elif command -v eopkg >/dev/null 2>&1; then
			sudo eopkg remove -y go >/dev/null 2>&1
		fi

		if command -v snap >/dev/null 2>&1; then
			sudo snap remove go >/dev/null 2>&1
		fi

		if command -v flatpak >/dev/null 2>&1; then
			flatpak remove -y org.golang.go >/dev/null 2>&1
		fi

		[ -d "/usr/local/go" ] && sudo rm -rf /usr/local/go
	fi

	for BINARY in go gofmt; do
		for PATH_DIR in /bin /usr/bin /usr/local/bin /opt/homebrew/bin /snap/bin; do
			[ -L "$PATH_DIR/$BINARY" ] || [ -f "$PATH_DIR/$BINARY" ] && sudo rm -f "$PATH_DIR/$BINARY"
		done
	done

	[ -d "$GOPATH" ] && sudo rm -rf "${GOPATH:?}"/*
}

function DOWNLOAD_GO() {
	if ! command -v wget >/dev/null 2>&1 && ! command -v curl >/dev/null 2>&1; then
		echo "Error: wget or curl required"
		exit
	fi

	case "$OS" in
	"linux")
		DOWNLOAD_URLS=(
			"https://dl.google.com/go/go${GO_VER}.linux-${ARCH}.tar.gz"
			"https://golang.google.cn/dl/go${GO_VER}.linux-${ARCH}.tar.gz"
			"https://mirrors.aliyun.com/golang/go${GO_VER}.linux-${ARCH}.tar.gz"
			"https://mirrors.ustc.edu.cn/golang/go${GO_VER}.linux-${ARCH}.tar.gz"
		)
		;;
	"darwin")
		DOWNLOAD_URLS=(
			"https://dl.google.com/go/go${GO_VER}.darwin-${ARCH}.tar.gz"
			"https://golang.google.cn/dl/go${GO_VER}.darwin-${ARCH}.tar.gz"
			"https://mirrors.aliyun.com/golang/go${GO_VER}.darwin-${ARCH}.tar.gz"
			"https://mirrors.ustc.edu.cn/golang/go${GO_VER}.darwin-${ARCH}.tar.gz"
		)
		;;
	*)
		echo "Error: Unsupported operating system ${OS}"
		exit
		;;
	esac

	local download_success=false
	for DOWNLOAD_URL in "${DOWNLOAD_URLS[@]}"; do
		if command -v wget >/dev/null 2>&1; then
			if wget --timeout=30 --tries=3 --quiet "$DOWNLOAD_URL" -O go.tar.gz; then
				download_success=true
				break
			fi
		else
			if curl -L --connect-timeout 30 --max-time 300 --silent "$DOWNLOAD_URL" -o go.tar.gz; then
				download_success=true
				break
			fi
		fi

		rm -f go.tar.gz
	done

	if [ "$download_success" = false ]; then
		echo "Error: All download addresses failed"
		exit
	fi

	[ ! -f go.tar.gz ] && echo "Error: Download file does not exist" && exit

	if ! sudo -n true 2>/dev/null; then
		echo "Error: sudo permissions required"
		exit
	fi

	sudo rm -rf /usr/local/go
	sudo tar -C /usr/local -xzf go.tar.gz || {
		echo "Extraction failed"
		rm -f go.tar.gz
		exit
	}
	rm -f go.tar.gz
}

function INSTALL_GO() {
	UNINSTALL_GO
	DOWNLOAD_GO

	[ ! -d "/usr/local/go" ] && echo "Error: Go installation failed" && exit

	if ! sudo -n true 2>/dev/null; then
		echo "Error: sudo permissions required"
		exit
	fi

	sudo ln -sf /usr/local/go/bin/go /usr/bin/go
	sudo ln -sf /usr/local/go/bin/gofmt /usr/bin/gofmt

	UPDATE_ALL_SHELL_CONFIGS

	go version >/dev/null 2>&1 || { echo "Error: Go installation verification failed" && exit; }
}

function CHECK_GO_VERSION() {
	if ! command -v go >/dev/null 2>&1; then
		INSTALL_GO
		return
	fi

	local version_output
	version_output=$(go version 2>/dev/null)
	if echo "$version_output" | grep -q "go${GO_VER}"; then
		if [ -z "$GOPATH" ]; then
			UPDATE_ALL_SHELL_CONFIGS
		fi
		return
	else
		INSTALL_GO
		return
	fi

}

if [[ "$OS" =~ mingw64_nt.* ]] || [[ "$OS" =~ msys_nt.* ]]; then
	export MSYS=winsymlinks:nativestrict
	MSYSTEM_CLEAN=$(echo "$MSYSTEM" | tr -d '[:space:]')
	if ! command -v sudo >/dev/null 2>&1; then
		echo '#!/usr/bin/env bash' >/usr/bin/sudo
		echo 'exec "$@"' >>/usr/bin/sudo
		chmod +x /usr/bin/sudo
	fi

	INSTALL_PACKAGES tar gzip unzip zip

	case "$MSYSTEM_CLEAN" in
	"ucrt64")
		if ! command -v go >/dev/null 2>&1; then
			pacman -Sy --noconfirm mingw-w64-ucrt-x86_64-go
			ln -sf /ucrt64/lib/go/bin/go /usr/bin/go
			ln -sf /ucrt64/lib/go/bin/gofmt /usr/bin/gofmt
			GO_INSTALL=true
		fi
		;;
	"mingw64")
		if ! command -v go >/dev/null 2>&1; then
			pacman -Sy --noconfirm mingw-w64-x86_64-go
			ln -sf /mingw64/lib/go/bin/go /usr/bin/go
			ln -sf /mingw64/lib/go/bin/gofmt /usr/bin/gofmt
			GO_INSTALL=true
		fi
		;;
	"mingw32")
		if ! command -v go >/dev/null 2>&1; then
			pacman -Sy --noconfirm mingw-w64-i686-go
			ln -sf /mingw32/lib/go/bin/go /usr/bin/go
			ln -sf /mingw32/lib/go/bin/gofmt /usr/bin/gofmt
			GO_INSTALL=true
		fi
		;;
	"clang64")
		if ! command -v go >/dev/null 2>&1; then
			pacman -Sy --noconfirm mingw-w64-clang-x86_64-go
			ln -sf /clang64/lib/go/bin/go /usr/bin/go
			ln -sf /clang64/lib/go/bin/gofmt /usr/bin/gofmt
			GO_INSTALL=true
		fi
		;;
	*)
		echo "Unsupported MSYS2 environment: $MSYSTEM_CLEAN"
		exit
		;;
	esac
	if [ "$GO_INSTALL" = true ] && [ ! -d "/opt/gopath" ]; then
		UPDATE_ALL_SHELL_CONFIGS
	fi
else
	INSTALL_PACKAGES tar gzip unzip zip
	CHECK_GO_VERSION
fi
