#!/bin/bash
if [ -t 0 ] && [ -t 1 ]; then
	export TERM=${TERM:-xterm}
	if [ -n "$BASH_VERSION" ]; then
		set -m 2>/dev/null
	fi
else
	export TERM=${TERM:-dumb}
fi

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
	if ! command -v sudo >/dev/null 2>&1; then
		echo "Insufficient permissions: sudo is required to run this script as root." >&2
		exit 1
	fi

	[[ ! -t 0 ]] && [[ -r /dev/tty ]] && exec 0</dev/tty

	persist_script_for_root() {
		local src="$1"
		local tmp
		tmp="$(mktemp "${TMPDIR:-/tmp}/dm-bootstrap.XXXXXX.sh")" || return 1
		chmod 0700 "$tmp" || {
			rm -f "$tmp"
			return 1
		}
		if ! cp -- "$src" "$tmp"; then
			rm -f "$tmp"
			return 1
		fi
		printf '%s\n' "$tmp"
	}

	declare spath="${BASH_SOURCE[0]:-$0}"
	if [[ "${spath}" != /* ]]; then
		dm_spdir="$(cd "$(dirname "${spath}")" && pwd 2>/dev/null)" || dm_spdir=""
		if [[ -n "${dm_spdir}" ]]; then
			spath="${dm_spdir}/$(basename "${spath}")"
		fi
	fi

	dm_script_ok() { [[ -f "${1:-}" ]] && grep -q 'INSTALL_PREREQUISITES()' "${1}" 2>/dev/null; }

	if dm_script_ok "${spath}"; then
		exec sudo -E bash -- "${spath}" "$@"
	fi

	if ! copy="$(persist_script_for_root "${spath}")"; then
		echo "Insufficient permissions: could not persist script for sudo (${spath}). Save dm.sh locally and run: sudo bash dm.sh (...)" >&2
		exit 1
	fi

	if ! dm_script_ok "${copy}"; then
		rm -f "${copy}"
		echo "This invocation is not supported (wrapped script?). Save dm.sh locally then: sudo bash dm.sh (...)" >&2
		exit 1
	fi

	exec sudo -E bash -- "${copy}" "$@"
fi

RED='\033[0;31m'
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

FILE_REDHAT_RELEASE=/etc/redhat-release
FILE_DEBIAN_VERSION=/etc/debian_version
FILE_ARMBIAN_RELEASE=/etc/armbian-release
FILE_RASPBERRYPI_OS_RELEASE=/etc/rpi-issue
FILE_OPENEULER_RELEASE=/etc/openEuler-release
FILE_OPENCLOUDOS_RELEASE=/etc/opencloudos-release
FILE_ANOLISOS_RELEASE=/etc/anolis-release
FILE_ORACLELINUX_RELEASE=/etc/oracle-release
FILE_ARCHLINUX_RELEASE=/etc/arch-release
FILE_ALPINE_RELEASE=/etc/alpine-release
FILE_PROXMOX_VERSION=/etc/pve/.version

PACKAGE_MANAGER=""

if [ -f "${FILE_DEBIAN_VERSION}" ] ||
	[ -f "${FILE_ARMBIAN_RELEASE}" ] ||
	[ -f "${FILE_RASPBERRYPI_OS_RELEASE}" ] ||
	[ -f "${FILE_PROXMOX_VERSION}" ]; then
	PACKAGE_MANAGER="apt"
elif [ -f "${FILE_REDHAT_RELEASE}" ] ||
	[ -f "${FILE_ORACLELINUX_RELEASE}" ] ||
	[ -f "${FILE_OPENEULER_RELEASE}" ] ||
	[ -f "${FILE_OPENCLOUDOS_RELEASE}" ] ||
	[ -f "${FILE_ANOLISOS_RELEASE}" ]; then
	PACKAGE_MANAGER="yum"
elif [ -f "${FILE_ARCHLINUX_RELEASE}" ]; then
	PACKAGE_MANAGER="pacman"
elif [ -f "${FILE_ALPINE_RELEASE}" ]; then
	PACKAGE_MANAGER="apk"
fi

if [ -z "$PACKAGE_MANAGER" ]; then
	echo -e "${RED}unsupported system version${NC}"
	echo -e "${RED}supported systems: ${NC}"
	echo -e "${RED}- debian/ubuntu/armbian/raspberry pi os/proxmox (apt)${NC}"
	echo -e "${RED}- redhat/centos/rocky/almalinux/oracle linux/openeuler/opencloudos/anolisos (yum/dnf)${NC}"
	echo -e "${RED}- arch linux (pacman)${NC}"
	echo -e "${RED}- alpine linux (apk)${NC}"
	echo -e "${YELLOW}press enter to continue...${NC}"
	read -r -p ""
	exit
fi

if ! command -v sudo >/dev/null 2>&1 || ! command -v bash >/dev/null 2>&1; then
	case "$PACKAGE_MANAGER" in
	"apt")
		apt-get update >/dev/null 2>&1
		apt-get install -y sudo bash >/dev/null 2>&1
		;;
	"yum")
		if command -v dnf >/dev/null 2>&1; then
			dnf install -y sudo bash >/dev/null 2>&1
		else
			yum install -y sudo bash >/dev/null 2>&1
		fi
		;;
	"pacman")
		pacman -Sy --noconfirm sudo bash >/dev/null 2>&1
		;;
	"apk")
		apk add sudo bash >/dev/null 2>&1
		;;
	*)
		echo -e "${RED}unsupported package manager${NC}"
		echo -e "${YELLOW}press enter to continue...${NC}"
		read -r -p ""
		exit
		;;
	esac
fi

INSTALL_PREREQUISITES() {
	if ! command -v jq >/dev/null 2>&1 || ! command -v curl >/dev/null 2>&1; then
		case "$PACKAGE_MANAGER" in
		"apt")
			sudo apt-get update >/dev/null 2>&1
			sudo apt-get install -y jq curl >/dev/null 2>&1
			;;
		"yum")
			if command -v dnf >/dev/null 2>&1; then
				sudo dnf install -y jq curl >/dev/null 2>&1
			else
				sudo yum install -y jq curl >/dev/null 2>&1
			fi
			;;
		"pacman")
			sudo pacman -Sy --noconfirm jq curl >/dev/null 2>&1
			;;
		"apk")
			sudo apk add jq curl >/dev/null 2>&1
			;;
		*)
			echo -e "${RED}unsupported system type${NC}"
			echo -e "${YELLOW}press enter to continue...${NC}"
			read -r -p ""
			exit
			;;
		esac
	fi

	if ! command -v docker >/dev/null 2>&1; then
		echo -e "${YELLOW}start installing docker...${NC}"
		echo -e "${BLUE}customize docker image storage directory?${NC}"

		while true; do
			echo -ne "${BLUE}press enter for default directory (optional): ${NC}"
			read -r custom_docker_dir

			if [[ -z "$custom_docker_dir" ]]; then
				break
			fi

			if [[ ! "$custom_docker_dir" =~ ^[a-zA-Z0-9._/-]+$ ]]; then
				echo -e "${RED}invalid directory path format${NC}"
				echo -e "${YELLOW}please enter a valid path or press enter for default${NC}"
				continue
			fi

			if [[ ! -d "$custom_docker_dir" ]]; then
				echo -e "${YELLOW}creating directory: $custom_docker_dir${NC}"
				if ! mkdir -p "$custom_docker_dir" 2>/dev/null; then
					echo -e "${RED}failed to create directory $custom_docker_dir${NC}"
					echo -e "${YELLOW}please enter a valid path or press enter for default${NC}"
					continue
				fi
			fi

			if [[ ! -w "$custom_docker_dir" ]]; then
				echo -e "${RED}directory $custom_docker_dir has no write permission${NC}"
				echo -e "${YELLOW}please enter a valid path or press enter for default${NC}"
				continue
			fi
			break
		done

		if [ "$PACKAGE_MANAGER" = "yum" ] || [ "$PACKAGE_MANAGER" = "apt" ]; then
			docker_install_cmd="bash <(curl -sSL https://raw.githubusercontent.com/jaman21/system-manager/main/di.sh)"
			if [ -n "$custom_docker_dir" ]; then
				if [ "$PACKAGE_MANAGER" = "yum" ]; then
					docker_install_cmd="$docker_install_cmd --close-firewall true"
				fi
				docker_install_cmd="$docker_install_cmd --data-root $custom_docker_dir"
			else
				if [ "$PACKAGE_MANAGER" = "yum" ]; then
					docker_install_cmd="$docker_install_cmd --close-firewall true"
				fi
			fi

			if ! eval "$docker_install_cmd"; then
				exit
			fi
		elif [ "$PACKAGE_MANAGER" = "pacman" ]; then
			if ! pacman -S docker --noconfirm; then
				echo -e "${RED}docker installation failed${NC}"
				exit
			fi

			if [ -n "$custom_docker_dir" ]; then
				mkdir -p "$custom_docker_dir"
				mkdir -p /etc/docker
				cat >/etc/docker/daemon.json <<EOF
{
    "data-root": "$custom_docker_dir"
}
EOF
			fi

			systemctl enable --now docker
		elif [ "$PACKAGE_MANAGER" = "apk" ]; then
			if ! apk add --no-cache docker docker-cli docker-compose; then
				echo -e "${RED}docker installation failed${NC}"
				echo -e "${YELLOW}press enter to continue...${NC}"
				read -r -p ""
				exit
			fi

			if [ -n "$custom_docker_dir" ]; then
				mkdir -p "$custom_docker_dir"
				mkdir -p /etc/docker
				cat >/etc/docker/daemon.json <<EOF
{
    "data-root": "$custom_docker_dir"
}
EOF
			fi

			rc-update add docker default
			rc-service docker start
		else
			echo -e "${RED}docker installation failed, unsupported system type${NC}"
			echo -e "${YELLOW}press enter to continue...${NC}"
			read -r -p ""
			exit
		fi

		if [ -f "/usr/libexec/docker/cli-plugins/docker-compose" ]; then
			sudo cp /usr/libexec/docker/cli-plugins/docker-compose /usr/local/bin/docker-compose
			sudo chmod +x /usr/local/bin/docker-compose
		else
			command -v docker-compose >/dev/null 2>&1 || {
				echo -e "${YELLOW}installing docker compose...${NC}"
				COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
				if ! sudo curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose ||
					! sudo chmod +x /usr/local/bin/docker-compose; then
					echo -e "${RED}docker compose installation failed${NC}"
					echo -e "${YELLOW}press enter to continue...${NC}"
					read -r -p ""
					exit
				fi
			}
		fi
	fi
}

INSTALL_PREREQUISITES

if [[ "${EUID:-$(id -u)}" -eq 0 ]] && [[ -n "${SUDO_USER:-}" ]] && command -v docker >/dev/null 2>&1; then
	if ! docker ps >/dev/null 2>&1 && sudo -u "$SUDO_USER" -H docker ps >/dev/null 2>&1; then
		dm_docker_bin="$(command -v docker)"
		docker() { sudo -u "$SUDO_USER" -H "$dm_docker_bin" "$@"; }
	fi
fi

dm_dest="/usr/local/bin/dm"
if [ ! -f "$dm_dest" ]; then
	if [ "$dm_installed" != true ] && command -v curl >/dev/null 2>&1; then
		if curl -fsSL "https://raw.githubusercontent.com/jaman21/system-manager/main/dm.sh" -o "$dm_dest" && chmod 755 "$dm_dest"; then
			dm_installed=true
		fi
	fi
	if [ "$dm_installed" = true ]; then
		echo -e "${BLUE}installing docker manager...${NC}"
		echo -e "${GREEN}docker manager has been installed to system${NC}"
		echo -e "${GREEN}next time run: sudo dm${NC}"
		echo -e "${YELLOW}press enter to continue...${NC}"
		read -r
		exit
	fi
fi

get_container_status() {
	docker inspect "$1" -f '{{.State.Status}}' 2>/dev/null || echo "unknown"
}

cleanup_resources() {
	local mode="${1:-single}"
	local dir_path="${2:-}"

	case "$mode" in
	single)
		if [ -n "$dir_path" ] && [ -d "$dir_path" ]; then
			rm -rf "$dir_path"
		fi
		;;
	all)
		find /tmp -maxdepth 1 -name "docker_temp_*" -type d -mmin +60 -exec rm -rf {} +
		;;
	docker)
		echo -e "${YELLOW}choose docker cleanup level:${NC}"
		echo "1) safe cleanup (only dangling resources)"
		echo "2) deep cleanup (all unused resources)"
		echo "3) cancel"
		read -r -p "choose [1]: " cleanup_level
		cleanup_level=${cleanup_level:-1}

		case "$cleanup_level" in
		1)
			echo "cleaning up dangling images..."
			docker image prune -f

			echo "cleaning up build cache..."
			docker builder prune -f

			echo "cleaning up unused volumes..."
			docker volume prune -f

			echo "cleaning up unused networks..."
			docker network prune -f
			;;
		2)
			read -r -p "confirm continue? (y/N): " confirm
			if [[ "$confirm" =~ ^[Yy]$ ]]; then
				echo "cleaning up all unused images..."
				docker image prune -a -f

				echo "cleaning up build cache..."
				docker builder prune -f

				echo "cleaning up all unused volumes..."
				docker volume prune -f

				echo "cleaning up all unused networks..."
				docker network prune -f
			else
				echo "cleanup operation cancelled"
			fi
			;;
		3)
			echo "cleanup operation cancelled"
			;;
		*)
			echo "invalid selection, cleanup operation cancelled"
			;;
		esac
		read -r -p "press enter to continue..."
		;;
	*)
		return 1
		;;
	esac
}

publish_docker() {
	while true; do
		read -r -p "project directory (full path required): " PROJECT_DIR
		if [[ -d "$PROJECT_DIR" ]]; then
			break
		else
			while true; do
				read -r -p "directory does not exist, retry input? (y/n): " RETRY
				case "$RETRY" in
				y | Y) break ;;
				n | N) return 1 ;;
				*) echo "please enter y or n" ;;
				esac
			done
		fi
	done

	DOCKERFILE="$PROJECT_DIR/Dockerfile"
	if [[ ! -f "$DOCKERFILE" ]]; then
		while true; do
			read -r -p "enter dockerfile filename in project directory: " DOCKERFILE_NAME
			DOCKERFILE="$PROJECT_DIR/$DOCKERFILE_NAME"
			if [[ -f "$DOCKERFILE" ]]; then
				break
			else
				while true; do
					read -r -p "file does not exist, retry input? (y/n): " RETRY
					case "$RETRY" in
					y | Y) break ;;
					n | N) return 1 ;;
					*) echo "please enter y or n" ;;
					esac
				done
			fi
		done
	fi

	CRED_FILE="/usr/local/bin/docker.json"
	if command -v jq >/dev/null 2>&1 && [ -f "$CRED_FILE" ] && [ -s "$CRED_FILE" ]; then
		mapfile -t USER_LIST < <(jq -r '.[].username' "$CRED_FILE" 2>/dev/null)
		COUNT=${#USER_LIST[@]}
		if [ "$COUNT" -gt 0 ]; then
			echo "found saved login credentials:"
			for i in $(seq 1 "$COUNT"); do
				echo "  $i) ${USER_LIST[$((i - 1))]}"
			done
			while true; do
				read -r -p "select (1-$COUNT) or s to skip: " SEL
				if [[ "$SEL" =~ ^[0-9]+$ ]] && [ "$SEL" -ge 1 ] && [ "$SEL" -le "$COUNT" ]; then
					USERNAME="${USER_LIST[$((SEL - 1))]}"
					PASSWORD=$(jq -r ".[$((SEL - 1))].password" "$CRED_FILE")
					break
				elif [[ "$SEL" = "s" || "$SEL" = "S" ]]; then
					break
				else
					echo "invalid number"
				fi
			done
		fi
	fi

	while true; do
		if [ -z "${USERNAME:-}" ]; then
			read -r -p "enter docker hub username: " USERNAME
			if [[ ! "$USERNAME" =~ ^[a-z0-9][a-z0-9-]{2,28}[a-z0-9]$ ]]; then
				echo "invalid username format"
				unset USERNAME
				continue
			fi
		fi
		if [ -z "${PASSWORD:-}" ]; then
			read -r -p "enter docker hub password/token: " PASSWORD
		fi
		if echo "$PASSWORD" | docker login -u "$USERNAME" --password-stdin >/dev/null 2>&1; then
			echo "login successful"
			if command -v jq >/dev/null 2>&1; then
				TMP_FILE=$(mktemp)
				if [ -f "$CRED_FILE" ] && [ -s "$CRED_FILE" ]; then
					IDX=$(jq -r --arg u "$USERNAME" 'map(.username) | index($u) // -1' "$CRED_FILE")
					if [ "$IDX" -ge 0 ] 2>/dev/null; then
						jq --arg u "$USERNAME" --arg p "$PASSWORD" '(.[] | select(.username==$u) | .password) = $p' "$CRED_FILE" >"$TMP_FILE" && mv "$TMP_FILE" "$CRED_FILE"
					else
						jq --arg u "$USERNAME" --arg p "$PASSWORD" '. + [{username:$u,password:$p}]' "$CRED_FILE" >"$TMP_FILE" && mv "$TMP_FILE" "$CRED_FILE"
					fi
				else
					echo "[{\"username\":\"$USERNAME\",\"password\":\"$PASSWORD\"}]" >"$CRED_FILE"
				fi
			else
				echo "note: jq not installed, skipping credential save"
			fi
			break
		else
			unset USERNAME
			unset PASSWORD
			while true; do
				read -r -p "login failed, retry? (y/n): " RETRY
				case "$RETRY" in
				y | Y) break ;;
				n | N) return 1 ;;
				*) echo "please enter y or n" ;;
				esac
			done
			continue
		fi
	done

	while true; do
		read -r -p "enter project name (e.g. app): " PROJECT_NAME
		if [[ "$PROJECT_NAME" =~ ^[a-z0-9][a-z0-9._-]*$ ]]; then
			REPO="$USERNAME/$PROJECT_NAME"
			break
		else
			echo "invalid project name, only lowercase letters, numbers, ._- allowed, must start with letter or number"
		fi
	done

	while true; do
		read -r -p "enter project tag [default: latest]: " TAG
		TAG=${TAG:-latest}
		if [[ "$TAG" =~ ^[A-Za-z0-9_.-]{1,128}$ ]]; then
			break
		else
			echo "invalid tag, only a-z a-z 0-9 . _ - allowed, max 128 characters"
		fi
	done

	ALSO_LATEST="N"
	if [[ "$TAG" != "latest" ]]; then
		while true; do
			read -r -p "also push latest tag? (y/n): " ALSO_LATEST
			case "$ALSO_LATEST" in
			y | Y | n | N) break ;;
			*) echo "please enter y or n" ;;
			esac
		done
	fi

	echo "choose target platform combination:"
	echo "  1) linux/amd64"
	echo "  2) linux/arm64"
	echo "  3) linux/386"
	echo "  4) linux/arm/v7"
	echo "  5) linux/amd64,linux/arm64,linux/386"
	echo "  6) linux/amd64,linux/arm64,linux/arm/v7"
	echo "  7) linux/amd64,linux/arm64,linux/386,linux/arm/v7"
	while true; do
		read -r -p "enter option number [default: 1]: " ARCH_SEL
		ARCH_SEL=${ARCH_SEL:-1}
		case "$ARCH_SEL" in
		1)
			PLATFORMS="linux/amd64"
			break
			;;
		2)
			PLATFORMS="linux/arm64"
			break
			;;
		3)
			PLATFORMS="linux/386"
			break
			;;
		4)
			PLATFORMS="linux/arm/v7"
			break
			;;
		5)
			PLATFORMS="linux/amd64,linux/arm64,linux/386"
			break
			;;
		6)
			PLATFORMS="linux/amd64,linux/arm64,linux/arm/v7"
			break
			;;
		7)
			PLATFORMS="linux/amd64,linux/arm64,linux/386,linux/arm/v7"
			break
			;;
		*) echo "invalid option" ;;
		esac
	done

	while true; do
		echo "user: $USERNAME"
		echo "repository: $REPO"
		echo "tag: $TAG"
		echo "platforms: $PLATFORMS"
		read -r -p "confirm start build and push? (Y/n): " CONFIRM
		case "$CONFIRM" in
		n | N) return 1 ;;
		*) break ;;
		esac
	done

	if [[ "$ALSO_LATEST" =~ ^[Yy]$ && "$TAG" != "latest" ]]; then
		docker buildx build --platform "$PLATFORMS" -t "$REPO:$TAG" -t "$REPO:latest" -f "$DOCKERFILE" "$PROJECT_DIR" --push
	else
		docker buildx build --platform "$PLATFORMS" -t "$REPO:$TAG" -f "$DOCKERFILE" "$PROJECT_DIR" --push
	fi

	read -r -p "publishing completed, press enter to continue..."
	return 0
}

stop_container() {
	local wait_time=${1:-2}

	local container_status
	container_status=$(get_container_status "$CONTAINER_ID")

	if [ "$container_status" = "running" ]; then
		if docker stop "$CONTAINER_ID" >/dev/null 2>&1; then
			sleep "$wait_time"

			if [ "$(docker inspect -f '{{.State.Status}}' "$CONTAINER_ID")" = "exited" ]; then
				return 0
			else
				echo -e "${RED}container $CONTAINER_ID stop failed${NC}"
				return 1
			fi
		else
			echo -e "${RED}cannot stop container $CONTAINER_ID${NC}"
			return 1
		fi
	else
		return 0
	fi
}

start_container() {
	local wait_time=${1:-3}
	local container_status
	container_status=$(get_container_status "$CONTAINER_ID")

	if [ "$container_status" = "running" ]; then
		return 0
	else
		if docker start "$CONTAINER_ID" >/dev/null 2>&1; then
			sleep "$wait_time"

			if [ "$(docker inspect -f '{{.State.Running}}' "$CONTAINER_ID")" = "true" ]; then
				echo "container $CONTAINER_ID started successfully"
				return 0
			else
				echo -e "${RED}container $CONTAINER_ID start failed${NC}"
				return 1
			fi
		else
			echo -e "${RED}cannot start container $CONTAINER_ID${NC}"
			return 1
		fi
	fi
}

start_container_with_config() {
	local container_status
	container_status=$(get_container_status "$CONTAINER_ID")

	if [ "$container_status" = "running" ]; then
		return 0
	fi

	start_container
}

handle_writable_layer_mount() {
	local container_id="$1"

	if ! command -v jq >/dev/null 2>&1; then
		echo -e "${RED}jq tool is required to parse json data${NC}"
		return 1
	fi

	if ! stop_container; then
		echo "failed to stop container"
		return 1
	fi

	local overlay_data
	overlay_data=$(docker inspect "$container_id" -f '{{json .GraphDriver.Data}}' 2>/dev/null)

	local upper_dir
	upper_dir=$(echo "$overlay_data" | jq -r '.UpperDir')
	local lower_dir
	lower_dir=$(echo "$overlay_data" | jq -r '.LowerDir')
	local work_dir
	work_dir=$(echo "$overlay_data" | jq -r '.WorkDir')

	if [ -z "$upper_dir" ] || [ ! -d "$upper_dir" ]; then
		echo "cannot get container filesystem information"
		return 1
	fi

	local mount_point="/mnt/docker_fs_${container_id}"
	if [ -d "$mount_point" ]; then
		rm -rf "$mount_point"
	fi
	mkdir -p "$mount_point"

	if ! mount -t overlay overlay \
		-o "lowerdir=$lower_dir,upperdir=$upper_dir,workdir=$work_dir" \
		"$mount_point" 2>/dev/null; then
		echo -e "${RED}mount failed, may be due to insufficient permissions or overlay filesystem not supported${NC}"
		echo "please ensure: "
		echo "1. run script with root privileges"
		echo "2. system supports overlay filesystem"
		echo "3. container filesystem information is complete"
		rm -rf "$mount_point"
		return 1
	fi

	echo -e "${YELLOW}choose access method:${NC}"
	echo -e "${GREEN}1) use local root environment${NC}"
	echo -e "${GREEN}2) use container root environment${NC}"
	echo -e "${GREEN}3) enter volume directory${NC}"
	read -r -p "$(tput setaf 3)choose (1/2/3) enter=2: $(tput sgr0)" choice

	case "$choice" in
	1)
		echo
		echo -e "${YELLOW}entered local root environment in container directory, type exit to quit${NC}"
		(cd "$mount_point" && /bin/bash)
		sync
		;;
	3)
		echo
		echo -e "${YELLOW}getting container volume information...${NC}"
		local volumes_info
		volumes_info=$(docker inspect "$container_id" -f '{{range .Mounts}}{{.Source}}|{{.Destination}}{{println}}{{end}}' 2>/dev/null)

		if [ -n "$volumes_info" ]; then
			local volume_count=0
			local volume_sources=()
			local volume_destinations=()

			while IFS='|' read -r vol_source vol_dest; do
				if [[ -n "$vol_source" && -n "$vol_dest" ]]; then
					volume_sources+=("$vol_source")
					volume_destinations+=("$vol_dest")
					((volume_count++))
				fi
			done < <(echo "$volumes_info")

			if [ $volume_count -eq 0 ]; then
				echo -e "${YELLOW}no valid volumes found${NC}"
			else
				echo -e "${BLUE}found $volume_count volumes:${NC}"
				for ((i = 0; i < volume_count; i++)); do
					echo -e "  $((i + 1))) ${volume_sources[i]} -> ${volume_destinations[i]}"
				done

				while true; do
					read -r -p "choose volume number to enter (1-$volume_count) or q to return: " vol_choice

					if [ "$vol_choice" = "q" ] || [ "$vol_choice" = "Q" ]; then
						break
					fi

					if [[ "$vol_choice" =~ ^[0-9]+$ ]] && [ "$vol_choice" -ge 1 ] && [ "$vol_choice" -le "$volume_count" ]; then
						local selected_index=$((vol_choice - 1))
						local selected_source="${volume_sources[selected_index]}"
						local selected_dest="${volume_destinations[selected_index]}"
						echo -e "${YELLOW}entering volume directory: $selected_source${NC}"
						echo -e "${BLUE}container path: $selected_dest${NC}"
						echo -e "${YELLOW}type exit to quit${NC}"

						(cd "$selected_source" && /bin/bash)
						sync
						break
					else
						echo -e "${RED}please enter valid number (1-$volume_count) or q to return${NC}"
					fi
				done
			fi
		else
			echo -e "${YELLOW}this container has no volumes configured${NC}"
		fi
		;;
	*)
		echo -e "${YELLOW}trying to enter container root environment, type exit to quit${NC}"

		[ -d "$mount_point/opt" ] || mkdir -p "$mount_point/opt"
		true >"$mount_point/opt/env.sh"
		local env_output
		env_output=$(docker inspect "$container_id" -f '{{range .Config.Env}}{{println .}}{{end}}' 2>/dev/null)
		if [ -n "$env_output" ]; then
			echo "$env_output" | while IFS= read -r line; do
				if [[ "$line" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]] && [[ ! "$line" =~ [%{}] ]]; then
					echo "export $line" >>"$mount_point/opt/env.sh"
				fi
			done
		fi

		DEFAULT_IFACE=$(ip route | grep default | awk '{print $5}' | head -1)
		if [ -n "$DEFAULT_IFACE" ]; then
			echo "export HOST_IFACE='$DEFAULT_IFACE'" >>"$mount_point/opt/env.sh"

			IP_INFO=$(ip addr show "$DEFAULT_IFACE" | grep "inet " | awk '{print $2}' | head -1)
			if [ -n "$IP_INFO" ]; then
				IP_ADDR=$(echo "$IP_INFO" | cut -d'/' -f1)
				NETMASK=$(echo "$IP_INFO" | cut -d'/' -f2)
				echo "ip addr add $IP_ADDR/$NETMASK dev $DEFAULT_IFACE 2>/dev/null" >>"$mount_point/opt/env.sh"
			fi

			GATEWAY=$(ip route | grep default | awk '{print $3}' | head -1)
			if [ -n "$GATEWAY" ]; then
				echo "ip route add default via $GATEWAY 2>/dev/null" >>"$mount_point/opt/env.sh"
			fi
		fi

		DNS_SERVERS=$(cat /etc/resolv.conf | grep nameserver | awk '{print $2}' | head -1)
		if [ -n "$DNS_SERVERS" ]; then
			echo "echo 'nameserver $DNS_SERVERS' > /etc/resolv.conf 2>/dev/null" >>"$mount_point/opt/env.sh"
		fi

		echo "mkdir -p /dev 2>/dev/null" >>"$mount_point/opt/env.sh"
		echo "mkdir -p /dev/pts 2>/dev/null" >>"$mount_point/opt/env.sh"
		mount -t proc proc "$mount_point/proc" 2>/dev/null
		mount -t sysfs sys "$mount_point/sys" 2>/dev/null
		mount -t devtmpfs dev "$mount_point/dev" 2>/dev/null
		mount -t devpts pts "$mount_point/dev/pts" 2>/dev/null
		mount -t tmpfs shm "$mount_point/dev/shm" 2>/dev/null
		mount --bind /tmp "$mount_point/tmp" 2>/dev/null

		echo "export LANG=C.UTF-8 2>/dev/null" >>"$mount_point/opt/env.sh"
		echo "export LC_ALL=C.UTF-8 2>/dev/null" >>"$mount_point/opt/env.sh"

		echo "if command -v apt-get >/dev/null 2>&1; then" >>"$mount_point/opt/env.sh"
		echo "  echo 'APT::Get::AllowUnauthenticated \"true\";' > /etc/apt/apt.conf.d/99allow-unauth 2>/dev/null" >>"$mount_point/opt/env.sh"
		echo "  echo 'Acquire::Check-Valid-Until \"false\";' >> /etc/apt/apt.conf.d/99allow-unauth 2>/dev/null" >>"$mount_point/opt/env.sh"
		echo "  echo 'APT::Get::AllowDowngrade \"true\";' >> /etc/apt/apt.conf.d/99allow-unauth 2>/dev/null" >>"$mount_point/opt/env.sh"
		echo "  apt-get update --allow-unauthenticated --allow-insecure-repositories 2>/dev/null" >>"$mount_point/opt/env.sh"
		echo "elif command -v yum >/dev/null 2>&1; then" >>"$mount_point/opt/env.sh"
		echo "  yum update --assumeyes --skip-broken 2>/dev/null" >>"$mount_point/opt/env.sh"
		echo "elif command -v dnf >/dev/null 2>&1; then" >>"$mount_point/opt/env.sh"
		echo "  dnf update --assumeyes --skip-broken 2>/dev/null" >>"$mount_point/opt/env.sh"
		echo "elif command -v apk >/dev/null 2>&1; then" >>"$mount_point/opt/env.sh"
		echo "  apk update 2>/dev/null" >>"$mount_point/opt/env.sh"
		echo "elif command -v pacman >/dev/null 2>&1; then" >>"$mount_point/opt/env.sh"
		echo "  pacman -Sy --noconfirm 2>/dev/null" >>"$mount_point/opt/env.sh"
		echo "elif command -v zypper >/dev/null 2>&1; then" >>"$mount_point/opt/env.sh"
		echo "  zypper refresh --non-interactive 2>/dev/null" >>"$mount_point/opt/env.sh"
		echo "fi" >>"$mount_point/opt/env.sh"

		cat >"$mount_point/opt/entrypoint.sh" <<'EOF'
#!/bin/sh

find_available_shell() {
    for shell in /bin/bash /bin/zsh /bin/ash /bin/sh; do
        [ -x "$shell" ] && echo "$shell" && return 0
    done
    return 1
}

SHELL_PATH=$(find_available_shell)
if [ -z "$SHELL_PATH" ]; then
    exit
fi

if [ -f /opt/env.sh ]; then
    set -a
    . /opt/env.sh
    set +a
fi

export PS1="(container-mount) \w \$ "
exec "$SHELL_PATH"
EOF
		chmod +x "$mount_point/opt/entrypoint.sh"
		chmod +x "$mount_point/opt/env.sh"
		chroot "$mount_point" "/opt/entrypoint.sh"

		sync
		for sub_mount in "$mount_point/proc" "$mount_point/sys" "$mount_point/dev/pts" "$mount_point/dev/shm" "$mount_point/tmp" "$mount_point/dev"; do
			if mountpoint -q "$sub_mount" 2>/dev/null; then
				umount -f "$sub_mount" 2>/dev/null
			fi
		done
		;;
	esac

	if umount -f "$mount_point" 2>/dev/null; then
		rm -rf "$mount_point"
	else
		echo -e "${RED}unmount failed${NC}"
		echo "attempting force unmount..."
		umount -l "$mount_point" 2>/dev/null
		if [ -d "$mount_point" ]; then
			echo "mount point still exists, showing contents: "
			ls -la "$mount_point"
		else
			echo -e "${GREEN}force unmount successful${NC}"
		fi
	fi

	start_container_with_config
}

get_container_by_number() {
	local choice="$1"

	if [[ "$choice" -lt 1 || "$choice" -gt "$G_CONTAINER_COUNT" ]]; then
		echo "invalid container selection"
		return 1
	fi

	local index=$((choice - 1))

	declare -g CONTAINER_ID="${G_CONTAINER_IDS[index]}"

	return 0
}

check_network_exists() {
	local network_name="$1"

	if docker network inspect "$network_name" >/dev/null 2>&1; then
		return 0
	else
		return 1
	fi
}

show_network_list() {
	echo "available networks: "
	echo

	G_NETWORK_IDS=()
	G_NETWORK_NAMES=()
	G_NETWORK_DRIVERS=()
	G_NETWORK_SCOPES=()

	while IFS= read -r line; do
		if [[ "$line" =~ ^[a-f0-9]{12,64} ]]; then
			local network_id
			network_id=$(echo "$line" | awk '{print $1}')
			local network_name
			network_name=$(echo "$line" | awk '{print $2}')
			local network_driver
			network_driver=$(echo "$line" | awk '{print $3}')
			local network_scope
			network_scope=$(echo "$line" | awk '{print $4}')

			if [[ -n "$network_id" && -n "$network_name" && -n "$network_driver" ]]; then
				G_NETWORK_IDS+=("$network_id")
				G_NETWORK_NAMES+=("$network_name")
				G_NETWORK_DRIVERS+=("$network_driver")
				G_NETWORK_SCOPES+=("$network_scope")
			fi
		fi
	done < <(docker network ls --format "table {{.ID}}\t{{.Name}}\t{{.Driver}}\t{{.Scope}}" | tail -n +2)

	if [ ${#G_NETWORK_IDS[@]} -eq 0 ]; then
		echo "no networks available in system!"
		return 1
	fi

	printf "%3s) %-20s | %-10s | %-10s | %s\n" "no." "network name" "driver" "scope" "network id"
	echo "----------------------------------------------------------------"

	for ((i = 0; i < ${#G_NETWORK_IDS[@]}; i++)); do
		printf "%3d) %-20s | %-10s | %-10s | %s\n" \
			$((i + 1)) \
			"${G_NETWORK_NAMES[i]}" \
			"${G_NETWORK_DRIVERS[i]}" \
			"${G_NETWORK_SCOPES[i]}" \
			"${G_NETWORK_IDS[i]}"
	done

	echo

	G_NETWORK_COUNT=${#G_NETWORK_IDS[@]}
	while true; do
		read -r -p "select network number (1-$G_NETWORK_COUNT) or q to return: " choice

		if [ "$choice" = "q" ] || [ "$choice" = "Q" ]; then
			return 1
		fi

		if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "$G_NETWORK_COUNT" ]; then
			local index=$((choice - 1))
			SELECTED_NETWORK_NAME="${G_NETWORK_NAMES[index]}"
			SELECTED_NETWORK_DRIVER="${G_NETWORK_DRIVERS[index]}"
			return 0
		fi

		echo "please enter valid network number"
	done
}

show_container_list() {
	clear
	echo "Docker Container Management Tool"
	echo

	G_CONTAINER_IDS=()
	G_CONTAINER_STATUSES=()
	G_CONTAINER_IMAGES=()
	G_CONTAINER_NAMES=()

	while IFS= read -r container_id; do
		if [ -n "$container_id" ]; then
			G_CONTAINER_IDS+=("$container_id")

			local container_status
			container_status=$(get_container_status "$container_id")
			local container_image
			container_image=$(docker inspect "$container_id" -f '{{.Config.Image}}' 2>/dev/null || echo "unknown")
			local container_name
			container_name=$(docker inspect "$container_id" -f '{{.Name}}' 2>/dev/null | sed 's/\///' || echo "unknown")

			G_CONTAINER_STATUSES+=("$container_status")
			G_CONTAINER_IMAGES+=("$container_image")
			G_CONTAINER_NAMES+=("$container_name")
		fi
	done < <(docker ps -a -q 2>/dev/null)

	if [ ${#G_CONTAINER_IDS[@]} -eq 0 ]; then
		echo "no containers in system, please install new container"
		if install_container; then
			show_container_list
		fi
		return 0
	fi

	G_CONTAINER_COUNT=${#G_CONTAINER_IDS[@]}
	if [ "$G_CONTAINER_COUNT" -eq 1 ]; then
		if get_container_by_number 1; then
			return 0
		else
			return 1
		fi
	fi

	for ((i = 0; i < ${#G_CONTAINER_IDS[@]}; i++)); do
		local display_status
		if [ "${G_CONTAINER_STATUSES[i]}" = "running" ]; then
			display_status="running"
		else
			display_status="stopped"
		fi

		printf "%3d) %-8s | %-20s | %-12s | %s\n" \
			$((i + 1)) \
			"$display_status" \
			"${G_CONTAINER_NAMES[i]}" \
			"${G_CONTAINER_IDS[i]}" \
			"${G_CONTAINER_IMAGES[i]}"
	done

	echo

	G_CONTAINER_COUNT=${#G_CONTAINER_IDS[@]}
	while true; do
		read -r -p "enter container number (1-$G_CONTAINER_COUNT) or i to install new container, q to quit: " choice

		if [ "$choice" = "q" ] || [ "$choice" = "Q" ]; then
			if [ -n "$CONTAINER_ID" ]; then
				break
			else
				exit
			fi
		fi

		if [ "$choice" = "i" ] || [ "$choice" = "I" ]; then
			install_container
			show_container_list
		fi

		if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "$G_CONTAINER_COUNT" ]; then
			echo -e "${RED}invalid container number, please re-enter.${NC}"
			continue
		fi

		if ! get_container_by_number "$choice"; then
			echo -e "${RED}failed to get container information, please re-select.${NC}"
			continue
		fi

		if ! docker inspect "$CONTAINER_ID" -f '{{.Image}}' >/dev/null 2>&1; then
			echo -e "${RED}cannot get container information, container may have been deleted, please re-select.${NC}"
			continue
		fi

		break
	done

	# 如果成功选择了容器，返回成功状态
	if [[ -n "$CONTAINER_ID" ]]; then
		return 0
	else
		return 1
	fi
}

show_container_config() {
	echo

	local container_name
	container_name=$(docker inspect "$CONTAINER_ID" -f '{{.Name}}' 2>/dev/null | sed 's/\///' || echo)
	local container_image
	container_image=$(docker inspect "$CONTAINER_ID" -f '{{.Config.Image}}' 2>/dev/null || echo "unknown")
	local container_status
	container_status=$(get_container_status "$CONTAINER_ID")

	if [ -z "$container_name" ] || [ -z "$container_image" ]; then
		echo -e "\033[0;33mcannot get complete container information\033[0m"
		return 1
	fi

	echo -e "${GREEN}container id:${NC} $CONTAINER_ID"
	echo -e "${GREEN}container name:${NC} $container_name"
	echo -e "${GREEN}container status:${NC} $container_status"
	echo -e "${GREEN}image name:${NC} $container_image"

	local entrypoint
	entrypoint=$(docker inspect "$CONTAINER_ID" -f '{{range .Config.Entrypoint}}{{.}} {{end}}' 2>/dev/null)
	if [ -n "$entrypoint" ]; then
		echo -e "${BLUE}entrypoint:${NC} $entrypoint"
	fi

	local cmd
	cmd=$(docker inspect "$CONTAINER_ID" -f '{{range .Config.Cmd}}{{.}} {{end}}' 2>/dev/null)
	if [ -n "$cmd" ]; then
		echo -e "${BLUE}command:${NC} $cmd"
	fi

	local env_output
	env_output=$(docker inspect "$CONTAINER_ID" -f '{{range .Config.Env}}{{println .}}{{end}}' 2>/dev/null)
	if [ -n "$env_output" ]; then
		echo -e "${YELLOW}environment variables:${NC}"
		echo "$env_output"
	fi

	local port_output
	port_output=$(docker inspect "$CONTAINER_ID" -f '{{range $p, $conf := .NetworkSettings.Ports}}{{$p}} -> {{$conf}}{{println}}{{end}}' 2>/dev/null)
	if [ -n "$port_output" ]; then
		echo -e "${YELLOW}port mapping:${NC}"
		echo "$port_output"
	fi

	local mount_output
	mount_output=$(docker inspect "$CONTAINER_ID" -f '{{range .Mounts}}{{.Source}} -> {{.Destination}}{{println}}{{end}}' 2>/dev/null)
	if [ -n "$mount_output" ]; then
		echo -e "${YELLOW}volume mounts:${NC}"
		echo "$mount_output"
	fi

	echo
}

modify_container_config() {
	clear
	echo "Docker Container Management Tool"
	echo

	while true; do
		echo "choose configuration to modify:"
		echo "1) rename container"
		echo "2) modify network mode"
		echo "3) set auto-start"
		echo "4) return to previous menu"
		echo "q) exit"
		echo

		read -r -p "choose (1-4/q): " config_choice

		if [ "$config_choice" = "q" ] || [ "$config_choice" = "Q" ]; then
			return 0
		fi

		case $config_choice in
		1)
			read -r -p "enter new container name: " new_container_name
			if [[ -z "$new_container_name" ]]; then
				echo "container name cannot be empty"
				read -r -p "press enter to continue..."
				continue
			fi
			if docker rename "$CONTAINER_ID" "$new_container_name"; then
				echo -e "${GREEN}container renamed successfully${NC}"
				read -r -p "press enter to continue..."
			else
				echo -e "${RED}container rename failed${NC}"
				read -r -p "press enter to continue..."
			fi
			;;

		2)
			echo "choose new network mode: "
			echo "1) select existing network"
			echo "2) create new network"
			echo "q) return"
			echo

			read -r -p "choose (1-2/q): " network_mode_choice

			if [ "$network_mode_choice" = "q" ] || [ "$network_mode_choice" = "Q" ]; then
				continue
			fi

			local new_network=""

			case $network_mode_choice in
			1)
				if show_network_list; then
					echo -e "${GREEN}selected network: $SELECTED_NETWORK_NAME${NC}"
					new_network="$SELECTED_NETWORK_NAME"
				else
					echo "network selection cancelled"
					read -r -p "press enter to continue..."
					continue
				fi
				;;
			2)
				while true; do
					read -r -p "enter new network name: " new_network_name
					if [[ -z "$new_network_name" ]]; then
						echo "network name cannot be empty"
						continue
					fi

					if check_network_exists "$new_network_name"; then
						echo -e "${RED}network name '$new_network_name' already exists${NC}"
						read -r -p "re-enter network name, press enter to continue..."
						continue
					fi

					break
				done

				echo "choose network driver type: "
				echo "1) bridge"
				echo "2) host"
				echo "3) overlay"
				echo "4) macvlan"
				echo "5) ipvlan"
				echo "6) none"
				echo "q) return"
				echo

				read -r -p "choose (1-6/q): " driver_choice

				if [ "$driver_choice" = "q" ] || [ "$driver_choice" = "Q" ]; then
					continue
				fi

				case $driver_choice in
				1) network_driver="bridge" ;;
				2) network_driver="host" ;;
				3) network_driver="overlay" ;;
				4) network_driver="macvlan" ;;
				5) network_driver="ipvlan" ;;
				6) network_driver="none" ;;
				*)
					echo "invalid choice, using default bridge driver"
					network_driver="bridge"
					;;
				esac

				echo "creating network '$new_network_name' (driver: $network_driver)..."
				if docker network create --driver "$network_driver" "$new_network_name"; then
					echo -e "${GREEN}network '$new_network_name' created successfully${NC}"
					new_network="$new_network_name"
				else
					echo -e "${RED}network creation failed${NC}"
					read -r -p "press enter to continue..."
					continue
				fi
				;;
			*)
				read -r -p "press enter to continue..."
				continue
				;;
			esac

			if [[ -n "$new_network" ]]; then
				if stop_container; then
					local current_networks
					current_networks=$(docker inspect "$CONTAINER_ID" -f '{{range $net, $config := .NetworkSettings.Networks}}{{$net}} {{end}}' 2>/dev/null)
					for net in $current_networks; do
						docker network disconnect "$net" "$CONTAINER_ID" 2>/dev/null
					done

					if docker network connect "$new_network" "$CONTAINER_ID"; then
						echo -e "${GREEN}network mode modified successfully${NC}"
						start_container
					else
						echo -e "${RED}network mode modification failed${NC}"
					fi
				fi
			fi
			read -r -p "press enter to continue..."
			;;

		3)
			read -r -p "set auto-start? (Y/n): " auto_restart
			if [ "$auto_restart" = "n" ] || [ "$auto_restart" = "N" ]; then
				if docker update --restart=no "$CONTAINER_ID"; then
					echo -e "${GREEN}auto-start cancelled${NC}"
				else
					echo -e "${RED}failed to cancel auto-start${NC}"
				fi
			else
				if docker update --restart=always "$CONTAINER_ID"; then
					echo -e "${GREEN}set to auto-start${NC}"
				else
					echo -e "${RED}failed to set auto-start${NC}"
				fi
			fi
			read -r -p "press enter to continue..."
			;;
		4)
			return 0
			;;
		*)
			echo "invalid choice, please try again"
			read -r -p "press enter to continue..."
			;;
		esac
	done
}

install_container() {
	clear
	echo "Docker Container Management Tool"
	echo

	local full_image_name=""
	while [[ -z "$full_image_name" ]]; do
		read -r -p "enter complete image name (e.g. openspeedtest/latest) (q to return): " full_image_name
		if [ "$full_image_name" = "q" ] || [ "$full_image_name" = "Q" ]; then
			return 1
		fi
		if [[ -z "$full_image_name" ]]; then
			echo -e "${RED}image name cannot be empty${NC}"
		fi
	done

	echo -e "${GREEN}pulling image: $full_image_name${NC}"
	if ! docker pull "$full_image_name"; then
		echo -e "${RED}image pull failed${NC}"
		read -r -p "press enter to continue..."
		install_container
		return 0
	fi

	echo
	read -r -p "enter container name (leave empty for auto-generation): " container_name
	local name_option=""
	if [[ -n "$container_name" ]]; then
		if [[ "$container_name" =~ ^[a-zA-Z0-9][a-zA-Z0-9_.-]*$ ]]; then
			if docker ps -a --format "{{.Names}}" | grep -q "^${container_name}$"; then
				echo -e "${RED}container name '$container_name' already exists${NC}"
				while true; do
					read -r -p "choose action: 1) re-enter name 2) use auto-generated name 3) exit (1/2/3): " name_choice
					case "$name_choice" in
					1)
						read -r -p "enter new container name: " container_name
						if [[ -n "$container_name" ]] && [[ "$container_name" =~ ^[a-zA-Z0-9][a-zA-Z0-9_.-]*$ ]]; then
							if docker ps -a --format "{{.Names}}" | grep -q "^${container_name}$"; then
								echo -e "${RED}container name '$container_name' still exists${NC}"
								continue
							else
								name_option="--name $container_name"
								break
							fi
						else
							echo -e "${RED}invalid container name format${NC}"
							continue
						fi
						;;
					2)
						echo "will use auto-generated container name"
						break
						;;
					3)
						echo "exit container installation"
						return 0
						;;
					*)
						echo "invalid choice, please enter 1, 2 or 3"
						;;
					esac
				done
			else
				name_option="--name $container_name"
			fi
		else
			echo -e "${RED}container name '$container_name' does not follow docker naming rules${NC}"
			read -r -p "use auto-generated name? (Y/q): " use_auto_name
			if [[ "$use_auto_name" = "q" && "$use_auto_name" != "Q" ]]; then
				return 1
			fi
		fi
	fi

	echo
	local env_options=""
	read -r -p "need to configure environment variables? (y/N): " need_env
	if [ "$need_env" = "y" ] || [ "$need_env" = "Y" ]; then
		echo "configure environment variables (key=value format)"
		echo "examples:"
		echo " HY2_DOMAIN=example.com"
		echo " HY2_AUTH=f4beaf21"
		echo
		while true; do
			read -r -p "enter environment variable: " env_var
			if [[ -z "$env_var" ]]; then
				echo -e "${RED}environment variable cannot be empty, please re-enter${NC}"
				continue
			fi

			if [[ "$env_var" =~ ^[A-Za-z_][A-Za-z0-9_]*=.*$ ]]; then
				if [[ -z "$env_options" ]]; then
					env_options="-e $env_var"
				else
					env_options="$env_options -e $env_var"
				fi
				echo -e "${GREEN}added environment variable: $env_var${NC}"

				while true; do
					read -r -p "need to add more environment variables? (y/n): " more_env
					case "$more_env" in
					Y | y) break ;;
					N | n) break 2 ;;
					*) echo -e "${RED}please enter y or n${NC}" ;;
					esac
				done
				if [[ "$more_env" = "N" || "$more_env" = "n" || "$more_env" = "" ]]; then
					break
				fi

			else
				echo -e "${RED}invalid environment variable format, use KEY=value format${NC}"
			fi
		done
	fi

	echo
	local entrypoint_option=""
	read -r -p "modify container entrypoint? (y/N): " modify_entrypoint
	if [ "$modify_entrypoint" = "y" ] || [ "$modify_entrypoint" = "Y" ]; then
		read -r -p "enter new entrypoint command (e.g. /bin/bash or python): " new_entrypoint
		[ -n "$new_entrypoint" ] && entrypoint_option="--entrypoint $new_entrypoint"
	fi

	echo
	local cmd_option=""
	read -r -p "modify container cmd? (y/N): " modify_cmd
	if [ "$modify_cmd" = "y" ] || [ "$modify_cmd" = "Y" ]; then
		read -r -p "enter new cmd command (e.g. -c 'echo hello' or /start.sh): " new_cmd
		[ -n "$new_cmd" ] && cmd_option="$new_cmd"
	fi

	echo
	local tty_option="-t"
	read -r -p "disable tty? (y/N): " disable_tty
	if [ "$disable_tty" = "y" ] || [ "$disable_tty" = "Y" ]; then
		tty_option=""
	fi

	echo
	local restart_option="--restart=always"
	read -r -p "set container auto-start? (Y/n): " auto_restart
	if [ "$auto_restart" = "n" ] || [ "$auto_restart" = "N" ]; then
		restart_option=""
	fi

	echo
	local network_option=""
	local selected_network_driver="bridge"
	read -r -p "need to configure network? (y/N): " need_network
	if [ "$need_network" = "y" ] || [ "$need_network" = "Y" ]; then
		echo "choose network mode: "
		echo "1) select existing network"
		echo "2) create new network"
		echo "q) skip network configuration"
		echo
		read -r -p "choose (1-2/q): " network_mode_choice

		if [[ "$network_mode_choice" != "q" && "$network_mode_choice" != "Q" ]]; then
			case $network_mode_choice in
			1)
				if show_network_list; then
					echo -e "${GREEN}selected network: $SELECTED_NETWORK_NAME${NC}"
					network_option="--network $SELECTED_NETWORK_NAME"
					selected_network_driver="$SELECTED_NETWORK_DRIVER"
				else
					echo "network selection cancelled"
				fi
				;;
			2)
				while true; do
					read -r -p "enter new network name: " new_network_name
					if [[ -z "$new_network_name" ]]; then
						echo "network name cannot be empty"
						continue
					fi
					if check_network_exists "$new_network_name"; then
						echo -e "${RED}network name '$new_network_name' already exists${NC}"
						read -r -p "re-enter network name, press enter to continue..."
						continue
					fi
					break
				done

				if [[ -n "$new_network_name" ]]; then
					echo "choose network driver type: "
					echo "1) bridge"
					echo "2) host"
					echo "3) overlay"
					echo "4) macvlan"
					echo "5) ipvlan"
					echo "6) none"
					echo "q) return"
					echo

					read -r -p "choose (1-6/q): " driver_choice

					if [[ "$driver_choice" != "q" && "$driver_choice" != "Q" ]]; then
						case $driver_choice in
						1) network_driver="bridge" ;;
						2) network_driver="host" ;;
						3) network_driver="overlay" ;;
						4) network_driver="macvlan" ;;
						5) network_driver="ipvlan" ;;
						6) network_driver="none" ;;
						*)
							echo "invalid choice, using default bridge driver"
							network_driver="bridge"
							;;
						esac

						echo "creating network '$new_network_name' (driver: $network_driver)..."
						if docker network create --driver "$network_driver" "$new_network_name"; then
							network_option="--network $new_network_name"
							selected_network_driver="$network_driver"
						else
							echo -e "${RED}network creation failed${NC}"
						fi
					else
						echo "network driver selection cancelled"
					fi
				fi
				;;
			*)
				echo "invalid choice"
				;;
			esac
		else
			echo "network configuration skipped"
		fi
	fi

	local port_options=""
	if [[ "$selected_network_driver" != "none" && "$selected_network_driver" != "host" ]]; then
		echo
		echo -e "${YELLOW}network mode $selected_network_driver requires port mapping${NC}"

		while true; do
			while true; do
				read -r -p "enter host port: " host_port
				if [[ -z "$host_port" ]]; then
					echo -e "${RED}host port cannot be empty, please re-enter${NC}"
					continue
				fi
				if ! [[ "$host_port" =~ ^[0-9]+$ ]]; then
					echo -e "${RED}host port must be numeric, please re-enter${NC}"
					continue
				fi
				break
			done

			while true; do
				read -r -p "enter container port: " container_port
				if [[ -z "$container_port" ]]; then
					echo -e "${RED}container port cannot be empty, please re-enter${NC}"
					continue
				fi
				if ! [[ "$container_port" =~ ^[0-9]+$ ]]; then
					echo -e "${RED}container port must be numeric, please re-enter${NC}"
					continue
				fi
				break
			done

			if [[ -z "$port_options" ]]; then
				port_options="-p $host_port:$container_port"
			else
				port_options="$port_options -p $host_port:$container_port"
			fi

			echo -e "${GREEN}added port mapping: $host_port:$container_port${NC}"

			while true; do
				read -r -p "need to map more ports? (y/n): " more_ports
				case "$more_ports" in
				Y | y) break ;;
				N | n) break 2 ;;
				*) echo -e "${RED}please enter y or n${NC}" ;;
				esac
			done

			if [[ "$more_ports" = "N" || "$more_ports" = "n" || "$more_ports" = "" ]]; then
				break
			fi
		done
	fi

	echo
	local volume_options=""
	read -r -p "need to configure mount points? (y/N): " need_volumes
	if [ "$need_volumes" = "y" ] || [ "$need_volumes" = "Y" ]; then
		echo "configure bind mounts (host directory -> container directory)"
		while true; do
			read -r -p "enter host directory path (absolute path): " host_path
			if [[ -z "$host_path" ]] || [[ ! "$host_path" =~ ^/[a-zA-Z0-9._/-]+$ ]]; then
				echo -e "${RED}host path error${NC}"
				continue
			fi

			if [[ ! -d "$host_path" ]]; then
				if mkdir -p "$host_path"; then
					echo -e "${GREEN}host directory created successfully: $host_path${NC}"
				else
					echo -e "${RED}host directory creation failed${NC}"
					continue
				fi
			fi

			read -r -p "enter container directory path: " container_path
			if [[ -z "$container_path" ]] || [[ ! "$container_path" =~ ^/[a-zA-Z0-9._/-]+$ ]]; then
				echo -e "${RED}container path error${NC}"
				continue
			fi

			if [[ -z "$volume_options" ]]; then
				volume_options="-v $host_path:$container_path"
			else
				volume_options="$volume_options -v $host_path:$container_path"
			fi

			echo -e "${GREEN}added bind mount: $host_path -> $container_path${NC}"

			while true; do
				read -r -p "need to add more mount points? (y/n): " more_volumes
				case "$more_volumes" in
				Y | y) break ;;
				N | n) break 2 ;;
				*) echo -e "${RED}please enter y or n${NC}" ;;
				esac
			done

			if [[ "$more_volumes" = "N" || "$more_volumes" = "n" || "$more_volumes" = "" ]]; then
				break
			fi
		done
	fi

	local create_cmd="docker run $tty_option -d $name_option $entrypoint_option $env_options $network_option $restart_option $port_options $volume_options $full_image_name $cmd_option"
	echo -e "${GREEN}executing command: $create_cmd${NC}"

	if ! container_id_tmp=$($create_cmd); then
		echo -e "${RED}container creation failed${NC}"
		return 1
	else
		CONTAINER_ID="$container_id_tmp"
		echo -e "${GREEN}container installation completed${NC}"
		read -r -p "press enter to continue..."
	fi
}

clear_container_logs() {
	echo "clearing logs for container $CONTAINER_ID..."

	if ! stop_container; then
		echo -e "${RED}failed to stop container, cannot clear logs${NC}"
		return 1
	fi

	local log_path
	log_path=$(docker inspect --format='{{.LogPath}}' "$CONTAINER_ID" 2>/dev/null)

	if [[ -z "$log_path" ]]; then
		echo -e "${RED}cannot get log path for container $CONTAINER_ID${NC}"
		return 1
	fi

	if [ -f "$log_path" ]; then
		if sudo truncate -s 0 "$log_path"; then
			:
		else
			echo -e "${RED}failed to clear log file, may need root permission: $log_path${NC}"
			return 1
		fi
	else
		echo -e "${YELLOW}log file does not exist or is empty: $log_path${NC}"
	fi

	start_container_with_config
	return 0
}

show_main_menu() {
	clear
	echo "Docker Container Management Tool"
	echo

	if [[ -n "$CONTAINER_ID" ]] && docker inspect "$CONTAINER_ID" >/dev/null 2>&1; then
		local container_name
		container_name=$(docker inspect "$CONTAINER_ID" -f '{{.Name}}' 2>/dev/null | sed 's/\///' || echo "unknown")
		local container_image
		container_image=$(docker inspect "$CONTAINER_ID" -f '{{.Config.Image}}' 2>/dev/null || echo "unknown")
		local container_status
		container_status=$(get_container_status "$CONTAINER_ID")

		local status_display
		if [ "$container_status" = "running" ]; then
			status_display="running"
		else
			status_display="stopped"
		fi

		echo -e "${GREEN}current container:${NC}"
		echo -e "${GREEN}id: ${BLUE}$CONTAINER_ID${NC}"
		echo -e "${GREEN}name: ${BLUE}$container_name${NC}"
		echo -e "${GREEN}image: ${BLUE}$container_image${NC}"
		echo -e "${GREEN}status: ${BLUE}$status_display${NC}"
		echo
	fi

	echo "choose operation:"
	echo "1) container log"
	echo "2) enter container"
	echo "3) writable layer mount"
	echo "4) select container"
	echo "5) install container"
	echo "6) configure container"
	echo "7) start container"
	echo "8) stop container"
	echo "9) delete container"
	echo "p) publish image"
	echo "c) clean up images"
	echo "q) exit program"
}

show_log_menu() {
	clear
	echo "Docker Container Management Tool"
	echo

	if [[ -n "$CONTAINER_ID" ]] && docker inspect "$CONTAINER_ID" >/dev/null 2>&1; then
		local container_name
		container_name=$(docker inspect "$CONTAINER_ID" -f '{{.Name}}' 2>/dev/null | sed 's/\///' || echo "unknown")
		local container_image
		container_image=$(docker inspect "$CONTAINER_ID" -f '{{.Config.Image}}' 2>/dev/null || echo "unknown")
		local container_status
		container_status=$(get_container_status "$CONTAINER_ID")

		local status_display
		if [ "$container_status" = "running" ]; then
			status_display="running"
		else
			status_display="stopped"
		fi

		echo -e "${GREEN}current container:${NC}"
		echo -e "${GREEN}id: ${BLUE}$CONTAINER_ID${NC}"
		echo -e "${GREEN}name: ${BLUE}$container_name${NC}"
		echo -e "${GREEN}image: ${BLUE}$container_image${NC}"
		echo -e "${GREEN}status: ${BLUE}$status_display${NC}"
		echo
	fi

	echo "choose log operation:"
	echo "1) view last 50 lines of logs"
	echo "2) view all logs"
	echo "3) real-time log tracking"
	echo "4) select container"
	echo "5) clear logs"
	echo "6) return to main menu"
	echo "q) exit program"
}

main() {
	local show_container=true
	while true; do
		if [[ -z "$CONTAINER_ID" ]] || [ "$show_container" = "true" ]; then
			if show_container_list; then
				show_main_menu
			else
				continue
			fi
		else
			show_main_menu
		fi
		read -r -p "choose operation (1-9/p/c/q): " access_mode

		case $access_mode in
		1)
			clear
			show_log_menu
			read -r -p "choose log operation (1-6/q): " log_choice

			case $log_choice in
			1)
				clear
				show_container_config
				echo "showing last 50 lines of logs..."
				echo "=========================================="
				docker logs --tail 50 "$CONTAINER_ID"
				echo
				echo "=========================================="
				read -r -p "press enter to return..."
				show_container=false
				continue
				;;
			2)
				clear
				show_container_config
				echo "showing all logs..."
				echo "=========================================="
				docker logs "$CONTAINER_ID"
				echo
				echo "=========================================="
				read -r -p "press enter to return..."
				show_container=false
				continue
				;;
			3)
				clear
				show_container_config
				echo "real-time log tracking, press ctrl+c to stop..."
				echo "=========================================="
				docker logs -f "$CONTAINER_ID"
				echo
				echo "=========================================="
				read -r -p "press enter to return..."
				show_container=false
				continue
				;;
			4)
				show_container=true
				return
				;;
			5)
				clear_container_logs
				show_container=false
				continue
				;;
			6)
				show_container=false
				continue
				;;
			q | Q)
				break
				;;
			*)
				show_container=false
				continue
				;;
			esac
			;;
		2)
			show_container_config
			if start_container; then
				if docker exec "$CONTAINER_ID" test -x /bin/bash 2>/dev/null; then
					if [ -t 0 ] && [ -t 1 ]; then
						docker exec -it "$CONTAINER_ID" /bin/bash 2>/dev/null
					else
						docker exec -i "$CONTAINER_ID" /bin/bash 2>/dev/null
					fi
					show_container=false
					continue
				elif docker exec "$CONTAINER_ID" test -x /bin/sh 2>/dev/null; then
					if [ -t 0 ] && [ -t 1 ]; then
						docker exec -it "$CONTAINER_ID" /bin/sh 2>/dev/null
					else
						docker exec -i "$CONTAINER_ID" /bin/sh 2>/dev/null
					fi
					show_container=false
					continue
				elif docker exec "$CONTAINER_ID" test -x /bin/ash 2>/dev/null; then
					if [ -t 0 ] && [ -t 1 ]; then
						docker exec -it "$CONTAINER_ID" /bin/ash 2>/dev/null
					else
						docker exec -i "$CONTAINER_ID" /bin/ash 2>/dev/null
					fi
					show_container=false
					continue
				elif docker exec "$CONTAINER_ID" test -x /bin/zsh 2>/dev/null; then
					if [ -t 0 ] && [ -t 1 ]; then
						docker exec -it "$CONTAINER_ID" /bin/zsh 2>/dev/null
					else
						docker exec -i "$CONTAINER_ID" /bin/zsh 2>/dev/null
					fi
					show_container=false
					continue
				fi
			fi

			echo -e "${YELLOW}cannot enter container normally, using mount method:${NC}"
			handle_writable_layer_mount "$CONTAINER_ID"
			show_container=false
			continue
			;;
		3)
			show_container_config
			handle_writable_layer_mount "$CONTAINER_ID"
			show_container=false
			continue
			;;
		4)
			show_container=true
			continue
			;;
		5)
			install_container
			show_container=false
			continue
			;;
		6)
			modify_container_config
			show_container=false
			continue
			;;
		7)
			show_container_config
			if start_container; then
				echo "container started successfully"
			fi
			show_container=false
			continue
			;;
		8)
			show_container_config
			if stop_container; then
				echo "container stopped successfully"
			fi
			show_container=false
			continue
			;;
		9)
			show_container_config
			read -r -p "confirm delete container? this operation cannot be undone! (y/N): " confirm
			if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
				if ! stop_container; then
					echo "failed to stop container"
					continue
				fi

				if docker rm -f "$CONTAINER_ID" >/dev/null 2>&1; then
					echo -e "${GREEN}container deleted successfully${NC}"
				else
					echo -e "${RED}container deletion failed${NC}"
				fi
			fi
			read -r -p "press enter to return to main menu..."
			show_container=false
			continue
			;;
		p | P)
			publish_docker
			show_container=false
			continue
			;;
		c | C)
			cleanup_resources docker
			show_container=false
			continue
			;;
		q | Q)
			echo
			break
			;;
		*)
			show_container=false
			continue
			;;
		esac
	done
}

main "$@"
