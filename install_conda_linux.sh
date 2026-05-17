#!/bin/bash
# shellcheck shell=bash
# shellcheck disable=SC2162,SC2063,SC1090,SC1091,SC2046,SC2126
if [ -f "/usr/bin/pacman" ] && [ -n "$MSYSTEM" ]; then
	echo "Error: This script is not designed for MSYS2 environment."
	echo "Current environment: $MSYSTEM"
	echo "Please use install_conda_msys2.sh instead for MSYS2 environment."
	exit 1
fi

OS_NAME=$(uname -s)
ARCH_NAME=$(uname -m)
detect_package_manager() {
	if [ -x "/usr/bin/pacman" ] && [ -f "/usr/bin/pacman" ]; then
		echo "pacman"
		return
	fi

	if [ -x "/usr/bin/apt" ] && [ -f "/usr/bin/apt" ]; then
		echo "apt"
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
	exit 1
}

SHELL_BASENAME=$(basename "$SHELL")
case "$SHELL_BASENAME" in
zsh)
	SHELL_RC="$HOME/.zshrc"
	;;
bash)
	# On macOS, bash often sources ~/.bash_profile; keep ~/.bashrc for consistency
	SHELL_RC="$HOME/.bashrc"
	;;
fish)
	SHELL_RC="$HOME/.config/fish/config.fish"
	;;
csh | tcsh)
	SHELL_RC="$HOME/.cshrc"
	;;
*)
	SHELL_RC="$HOME/.profile"
	;;
esac

# sed -i cross-platform compat
if [[ "$OS_NAME" == "Darwin" ]]; then
	SED_INPLACE=(sed -i '')
else
	SED_INPLACE=(sed -i)
fi

if [[ "$OS_NAME" == "Linux" ]]; then
	if ! command -v wget &>/dev/null; then
		pkg_manager=$(detect_package_manager)
		if [[ "$pkg_manager" == "apt" ]]; then
			sudo apt update -y && sudo apt install -y wget
		elif [[ "$pkg_manager" == "dnf" ]]; then
			sudo dnf install -y wget
		elif [[ "$pkg_manager" == "yum" ]]; then
			sudo yum install -y wget
		elif [[ "$pkg_manager" == "zypper" ]]; then
			sudo zypper refresh || true
			sudo zypper install -y wget
		elif [[ "$pkg_manager" == "eopkg" ]]; then
			sudo eopkg install -y wget
		elif [[ "$pkg_manager" == "pacman" ]]; then
			sudo pacman -Sy --noconfirm wget
		fi
	fi
fi

if [ "$(id -u)" -ne 0 ]; then
	export PIP_USER=true
else
	export PIP_USER=false
fi

MINICONDA_INSTALL_DIR="$HOME/miniconda3"
if [[ -x "${MINICONDA_INSTALL_DIR}/bin/conda" ]]; then
	PATH="${MINICONDA_INSTALL_DIR}/bin:${PATH}"
	export PATH
fi

get_conda_envs() {
	conda env list | awk '{print $1}' | grep -v '^#'
}

function configure_conda() {
	local env_name="${1:-base}"
	conda config --set auto_update_conda False
	conda config --set notify_outdated_conda False

	if ! conda config --show channels | grep -Eq '^[[:space:]]*- conda-forge$'; then
		conda config --add channels conda-forge
	fi
	if ! conda config --show channels | grep -Eq '^[[:space:]]*- anaconda$'; then
		conda config --add channels anaconda
	fi
	conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main
	conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r
	conda config --set channel_priority strict
	if [[ "$env_name" != "base" ]]; then
		conda run -n "$env_name" python -m pip install --upgrade pip
		conda install -n "$env_name" -y -c conda-forge libstdcxx-ng git openjdk
	else
		conda run python -m pip install --upgrade pip
		conda install -y -c conda-forge libstdcxx-ng git openjdk
	fi
}

create_env() {
	echo "Please enter the virtual environment name to create (no punctuation, underscores allowed):"
	read ENV_NAME

	if conda env list | grep -q "$ENV_NAME"; then
		echo "Virtual environment $ENV_NAME already exists, please choose another name."
		return
	fi
	echo "Please enter the Python version to install (e.g., 3.11):"
	read PYTHON_VERSION

	echo "Creating virtual environment $ENV_NAME ..."
	if conda create -n "$ENV_NAME" -c conda-forge python="$PYTHON_VERSION" dlib -y; then
		echo "conda activate $ENV_NAME" >>"$SHELL_RC"
		source "$(conda info --base)/etc/profile.d/conda.sh"
		if conda info --envs | grep -q '\*'; then
			conda deactivate
		fi
		conda activate "$ENV_NAME"
		configure_conda "$ENV_NAME"
		echo "Virtual environment $ENV_NAME created successfully!"
		echo -e "\033[31mPlease restart the console\033[0m"
	else
		echo "Failed to create virtual environment $ENV_NAME"
		return
	fi
}

delete_env() {
	echo "Please enter the virtual environment name to delete:"
	read ENV_NAME

	CURRENT_ENV=$(conda info --envs | grep '*' | awk '{print $1}')
	if [[ "$CURRENT_ENV" == "$ENV_NAME" ]]; then
		if [[ $(conda info --envs | grep '*' | wc -l) -gt 0 ]]; then
			echo "Current virtual environment is $ENV_NAME, exiting this environment..."
			if ! conda info --envs | grep -q "$ENV_NAME"; then
				conda init
				source ~/.bashrc
			fi
			source "$(conda info --base)/etc/profile.d/conda.sh"
			conda deactivate
		fi
	fi

	echo "Deleting virtual environment $ENV_NAME ..."
	conda remove --name "$ENV_NAME" --all -y
	"${SED_INPLACE[@]}" "/conda activate $ENV_NAME/d" "$SHELL_RC"
	echo -e "\033[31mPlease restart the console\033[0m"
}

if command -v conda &>/dev/null; then
	while true; do
		echo "Please select an operation:"
		echo "1. Create virtual environment"
		echo "2. Delete virtual environment"
		echo "3. Show installed virtual environments"
		echo "4. Exit"
		# shellcheck disable=SC2162
		read -p "Please enter option (1-4): " choice

		case $choice in
		1)
			create_env
			;;
		2)
			delete_env
			;;
		3)
			echo "Installed virtual environments:"
			ENV_LIST=$(get_conda_envs)
			if [ -z "$ENV_LIST" ]; then
				echo "No virtual environments found"
			else
				ENV_COUNT=$(echo "$ENV_LIST" | wc -l)
				if [ "$ENV_COUNT" -ge 1 ]; then
					echo "Select an environment to activate:"
					mapfile -t ENV_ARRAY <<<"$ENV_LIST"
					FILTERED_ARRAY=()
					for NAME in "${ENV_ARRAY[@]}"; do
						if [[ -n "$NAME" && "$NAME" != *[[:space:]]* ]]; then
							FILTERED_ARRAY+=("$NAME")
						fi
					done
					IDX=1
					for NAME in "${FILTERED_ARRAY[@]}"; do
						echo "$IDX) $NAME"
						IDX=$((IDX + 1))
					done
					read -p "Enter number to activate (or press Enter to skip): " SEL
					if [[ -n "$SEL" && "$SEL" =~ ^[0-9]+$ ]] && [ "$SEL" -ge 1 ] && [ "$SEL" -le "${#FILTERED_ARRAY[@]}" ]; then
						TARGET_ENV="${FILTERED_ARRAY[$((SEL - 1))]}"
						"${SED_INPLACE[@]}" '/conda activate/d' "$SHELL_RC"
						echo "conda activate $TARGET_ENV" >>"$SHELL_RC"
						echo "Activated environment: $TARGET_ENV (persisted to $SHELL_RC)"
					fi
					echo -e "\033[31mPlease restart the console\033[0m"
				fi
			fi
			;;
		4)
			break
			;;
		*)
			echo "Invalid option, please select again."
			;;
		esac
	done
else
	echo "conda is not installed, installing Miniconda..."
	INSTALLER_URL=""
	case "$OS_NAME" in
	Linux)
		if [[ "$ARCH_NAME" == "x86_64" || "$ARCH_NAME" == "amd64" ]]; then
			# INSTALLER_URL="https://repo.anaconda.com/miniconda/Miniconda3-py312_25.5.1-1-Linux-x86_64.sh"
			INSTALLER_URL="https://repo.anaconda.com/miniconda/Miniconda3-py312_26.1.1-1-Linux-x86_64.sh"
		elif [[ "$ARCH_NAME" == "aarch64" || "$ARCH_NAME" == "arm64" ]]; then
			# INSTALLER_URL="https://repo.anaconda.com/miniconda/Miniconda3-py312_25.5.1-1-Linux-aarch64.sh"
			INSTALLER_URL="https://repo.anaconda.com/miniconda/Miniconda3-py312_26.1.1-1-Linux-aarch64.sh"
		else
			echo "Unsupported Linux architecture: $ARCH_NAME"
			exit 1
		fi
		;;
	Darwin)
		if [[ "$ARCH_NAME" == "arm64" ]]; then
			INSTALLER_URL="https://repo.anaconda.com/miniconda/Miniconda3-py312_25.5.1-1-MacOSX-arm64.sh"
		elif [[ "$ARCH_NAME" == "x86_64" ]]; then
			INSTALLER_URL="https://repo.anaconda.com/miniconda/Miniconda3-py312_25.5.1-1-MacOSX-x86_64.sh"
		else
			echo "Unsupported macOS architecture: $ARCH_NAME"
			exit 1
		fi
		;;
	*)
		echo "Unsupported OS: $OS_NAME"
		exit 1
		;;
	esac

	if command -v curl &>/dev/null; then
		curl -fsSL "$INSTALLER_URL" -o Miniconda3.sh
	elif command -v wget &>/dev/null; then
		wget -q "$INSTALLER_URL" -O Miniconda3.sh
	else
		echo "curl or wget is not installed, please install one of them"
		exit 1
	fi

	if [[ ! -f Miniconda3.sh ]]; then
		echo "Download failed, please check your network connection!"
		exit 1
	fi

	if [ -e "$MINICONDA_INSTALL_DIR" ]; then
		rm -Rf "$MINICONDA_INSTALL_DIR"
	fi

	echo "Installing Miniconda..."
	bash Miniconda3.sh -b -p "$MINICONDA_INSTALL_DIR"
	rm Miniconda3.sh
	export PATH="$PATH":"$MINICONDA_INSTALL_DIR/bin"

	conda init "$SHELL_BASENAME"
	if [[ -f "$SHELL_RC" ]]; then
		source "$SHELL_RC"
	fi

	configure_conda base

	echo -e "\033[31mPlease restart the console\033[0m"
fi
