#!/bin/bash
# shellcheck shell=bash
# shellcheck disable=SC2162,SC2063,SC2126,SC2086,SC2129

if [ ! -f "/usr/bin/pacman" ] || [ -z "$MSYSTEM" ]; then
  echo "Error: This script is designed for MSYS2 environment only."
  echo "Current environment: $MSYSTEM"
  echo "Please use install_conda_linux.sh instead for Linux/macOS environments."
  exit 1
fi

/usr/bin/pacman -S --needed --noconfirm wget sed coreutils
if [ "$(id -u)" -ne 0 ]; then
  export PIP_USER=true
else
  export PIP_USER=false
fi

MINICONDA_INSTALL_DIR="/c/msys64/home/$(whoami)/miniconda3"
if [[ -x "${MINICONDA_INSTALL_DIR}/bin/conda" ]]; then
  PATH="${MINICONDA_INSTALL_DIR}/bin:${PATH}"
  export PATH
fi

update_system_path() {
  local env_name="${1:-base}"
  local python_dir scripts_dir
  if [[ "$env_name" == "base" ]]; then
    python_dir="$MINICONDA_INSTALL_DIR"
    scripts_dir="$MINICONDA_INSTALL_DIR/Scripts"
  else
    python_dir="$MINICONDA_INSTALL_DIR/envs/$env_name"
    scripts_dir="$MINICONDA_INSTALL_DIR/envs/$env_name/Scripts"
  fi

  if [ ! -d "$python_dir" ] || [ ! -d "$scripts_dir" ]; then
    echo "Warning: Environment paths do not exist: $python_dir or $scripts_dir"
    return 1
  fi

  local python_dir_win scripts_dir_win
  python_dir_win=$(cygpath -w "$python_dir" 2>/dev/null | tr -d '\r\n')
  scripts_dir_win=$(cygpath -w "$scripts_dir" 2>/dev/null | tr -d '\r\n')

  if [ -z "$python_dir_win" ] || [ -z "$scripts_dir_win" ]; then
    echo "Error: Path conversion failed"
    return 1
  fi

  local python_dir_escaped scripts_dir_escaped
  python_dir_escaped="${python_dir_win//\'/\'\'}"
  scripts_dir_escaped="${scripts_dir_win//\'/\'\'}"

  echo "Updating system PATH for environment: $env_name"
  powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "
		\$ErrorActionPreference = 'Stop'
		try {
			# Target conda/env dirs to inject into PATH
			\$pythonDir = '$python_dir_escaped'
			\$scriptsDir = '$scripts_dir_escaped'
			\$newPaths = @(\$pythonDir, \$scriptsDir)
			
			if (-not \$pythonDir -or -not \$scriptsDir) {
				throw 'Invalid paths provided'
			}
			
			# Current user PATH from the environment store
			\$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
			if (-not \$userPath) { \$userPath = '' }
			
			# Heuristic: does this PATH entry look like Python/conda?
			\$IsPythonPath = {
				param([string]\$path)
				
				# Never treat Windows system trees as conda paths
				\$lowerPath = \$path.ToLower()
				\$sysRoot = \$env:SystemRoot.ToLower()
				if (\$lowerPath.StartsWith(\$sysRoot)) {
					return \$false
				}
				
				# Match typical Python / conda binaries in directory entries
				if (Test-Path \$path -PathType Container) {
					\$pythonExes = @('python.exe', 'python3.exe', 'python2.exe', 'conda.exe', '_conda.exe')
					foreach (\$exe in \$pythonExes) {
						if (Test-Path (Join-Path \$path \$exe) -PathType Leaf) {
							return \$true
						}
					}
				}
				return \$false
			}
			
			# Drop existing conda/python-like prefixes before prepending ours
			\$filteredPaths = (\$userPath -split ';' | Where-Object {
				\$path = \$_.Trim()
				if (-not \$path) { return \$false }
				-not (& \$IsPythonPath \$path)
			})
			
			# Trim trailing slashes for stable comparisons / joins
			\$Normalize = {
				param([array]\$paths)
				return (\$paths | ForEach-Object {
					if (\$_ -and \$_.Trim()) { \$_.TrimEnd('\\', '/') }
				} | Where-Object { \$_.Trim() })
			}
			
			\$normalizedFiltered = & \$Normalize \$filteredPaths
			\$normalizedNew = & \$Normalize \$newPaths
			
			# Prefer new paths first and remove duplicates case-insensitively
			\$pathList = @()
			\$pathSet = @{}
			\$allPaths = \$normalizedNew + \$normalizedFiltered
			foreach (\$path in \$allPaths) {
				if (\$path) {
					\$key = \$path.ToLower()
					if (-not \$pathSet.ContainsKey(\$key)) {
						\$pathSet[\$key] = \$true
						\$pathList += \$path
					}
				}
			}
			
			# Persist merged PATH and abort early if empty (avoid bricking PATH)
			\$finalPath = (\$pathList | Where-Object { \$_.Trim() }) -join ';'
			if (-not \$finalPath) {
				throw 'Final PATH is empty, operation aborted to prevent system damage'
			}
			
			[Environment]::SetEnvironmentVariable('Path', \$finalPath, 'User')
			Write-Host \"System PATH updated successfully for environment: $env_name\"
		} catch {
			Write-Error \"Failed to update PATH: \$_\"
			exit 1
		}
	"
}

get_conda_envs() {
  conda env list 2>/dev/null | awk '/^[a-zA-Z0-9_-]+[[:space:]]/ {print $1}'
}

create_env() {
  echo "Please enter the virtual environment name to create (no punctuation, underscores allowed):"
  read ENV_NAME

  if conda env list | grep -q "$ENV_NAME"; then
    echo "Virtual environment $ENV_NAME already exists, please choose another name."
    return
  fi

  sed -i '/conda activate/d' ~/.bashrc
  echo "Please enter the Python version to install (e.g., 3.11):"
  read PYTHON_VERSION

  echo "Creating virtual environment $ENV_NAME ..."
  conda create -n "$ENV_NAME" -c conda-forge python="$PYTHON_VERSION" dlib -y

  ENV_DIR="$MINICONDA_INSTALL_DIR/envs/$ENV_NAME"
  if [ -d "$ENV_DIR" ] && [ -f "$ENV_DIR/python.exe" ] && [ ! -f "$ENV_DIR/python3.exe" ]; then
    cp "$ENV_DIR/python.exe" "$ENV_DIR/python3.exe"
  fi

  update_system_path "$ENV_NAME"
  echo "conda activate $ENV_NAME" >>~/.bashrc
  echo "Virtual environment $ENV_NAME created successfully!"
  echo -e "\033[31mPlease restart the console\033[0m"
}

delete_env() {
  echo "Please enter the virtual environment name to delete:"
  read ENV_NAME

  CURRENT_ENV=$(conda info --envs | grep '*' | awk '{print $1}')
  if [[ "$CURRENT_ENV" == "$ENV_NAME" ]]; then
    if [[ $(conda info --envs | grep '*' | wc -l) -gt 0 ]]; then
      echo "Current virtual environment is $ENV_NAME, exiting this environment..."
      conda deactivate
    fi
  fi

  echo "Deleting virtual environment $ENV_NAME ..."
  conda remove --name "$ENV_NAME" --all -y
  sed -i "/conda activate $ENV_NAME/d" ~/.bashrc
  echo -e "\033[31mPlease restart the console\033[0m"
}

show_menu() {
  echo "Please select an operation:"
  echo "1. Create virtual environment"
  echo "2. Delete virtual environment"
  echo "3. Show installed virtual environments"
  echo "q. Exit"
}

if command -v conda &>/dev/null; then
  while true; do
    show_menu
    read -p "Please enter option (1-3): " choice

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
        echo "No virtual environments found (only base environment exists)"
      else
        ENV_COUNT=$(echo "$ENV_LIST" | wc -l)
        if [ "$ENV_COUNT" -ge 1 ]; then
          echo "Select an environment to activate:"
          mapfile -t ENV_ARRAY <<<"$ENV_LIST"
          IDX=1
          for NAME in "${ENV_ARRAY[@]}"; do
            if [[ -n "$NAME" ]]; then
              echo "$IDX) $NAME"
              IDX=$((IDX + 1))
            fi
          done
          read -p "Enter number to activate (or press Enter to skip): " SEL
          if [[ -n "$SEL" && "$SEL" =~ ^[0-9]+$ ]] && [ "$SEL" -ge 1 ] && [ "$SEL" -le "${#ENV_ARRAY[@]}" ]; then
            TARGET_ENV="${ENV_ARRAY[$((SEL - 1))]}"
            sed -i '/conda activate/d' ~/.bashrc
            echo "conda activate $TARGET_ENV" >>~/.bashrc
            update_system_path "$TARGET_ENV"
            echo "Activated environment: $TARGET_ENV (persisted to ~/.bashrc)"
            echo -e "\033[31mPlease restart the console\033[0m"
          fi
        fi
      fi
      ;;
    q | Q)
      break
      ;;
    *)
      echo "Invalid option, please select again."
      ;;
    esac
  done
else
  echo "conda is not installed, installing Miniconda..."
  wget -q https://repo.anaconda.com/miniconda/Miniconda3-py312_25.5.1-1-Windows-x86_64.exe -O Miniconda3.exe

  if [[ ! -f Miniconda3.exe ]]; then
    echo "Download failed, please check your network connection!"
    exit 1
  fi

  if [ -e "$MINICONDA_INSTALL_DIR" ]; then
    rm -Rf "$MINICONDA_INSTALL_DIR"
  fi

  EXE_POSIX=~/miniconda3/Uninstall-Miniconda3.exe
  if [ -f "$EXE_POSIX" ]; then
    EXE_WIN=$(cygpath -w "$EXE_POSIX" 2>/dev/null || echo "")
    if [ -n "$EXE_WIN" ]; then
      cmd.exe /C "\"$EXE_WIN\" /S" || true
    fi
  fi

  /c/Windows/system32/cmd.exe //c "Miniconda3.exe /InstallationType=JustMe /RegisterPython=0 /AddToPath=0 /S /D=C:\\msys64\\home\\%USERNAME%\\miniconda3"
  rm Miniconda3.exe
  sleep 5

  echo "# >>> conda initialize >>>" >>~/.bashrc
  echo "export PATH=\"$MINICONDA_INSTALL_DIR/Scripts:\$PATH\"" >>~/.bashrc
  echo "eval \"\$('$MINICONDA_INSTALL_DIR/Scripts/conda.exe' 'shell.bash' 'hook')\"" >>~/.bashrc
  echo "conda activate base" >>~/.bashrc

  update_system_path "base"
  echo "Configuring conda to disable auto-update..."
  "$MINICONDA_INSTALL_DIR/Scripts/conda.exe" config --set auto_update_conda False
  "$MINICONDA_INSTALL_DIR/Scripts/conda.exe" config --set notify_outdated_conda False

  if [ -f "$MINICONDA_INSTALL_DIR/python.exe" ] && [ ! -f "$MINICONDA_INSTALL_DIR/python3.exe" ]; then
    cp "$MINICONDA_INSTALL_DIR/python.exe" "$MINICONDA_INSTALL_DIR/python3.exe"
  fi

  echo -e "\033[31mPlease restart the console\033[0m"
fi
