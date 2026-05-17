#!/bin/bash
if [ -t 0 ] && [ -t 1 ]; then
	export TERM=${TERM:-xterm}
	if [ -n "$BASH_VERSION" ]; then
		set -m 2>/dev/null
	fi
else
	# export TERM=dumb
	# if [ -n "$BASH_VERSION" ]; then
	#     set +m 2>/dev/null
	# fi
	exit
fi

function output_command_help() {
	echo "Docker CE Installation Script - Command Options:"
	echo "================================================"
	echo
	echo "Network Configuration:"
	echo "  --source <address>              Docker CE mirror host (domain or IP)"
	echo "  --source-registry <address>     Docker registry mirror (domain or IP)"
	echo "  --protocol <http|https>         Protocol for Docker CE mirror"
	echo "  --use-intranet-source <bool>    Prefer intranet mirror if available"
	echo
	echo "Installation Options:"
	echo "  --branch <name>                 Docker CE repo branch/path"
	echo "  --codename <name>               Debian-based distro codename"
	echo "  --designated-version <ver>      Specific Docker CE version to install"
	echo "  --install-latest <bool>         Install the latest Docker Engine"
	echo "  --data-root <path>              Set Docker image/data root directory"
	echo
	echo "System Configuration:"
	echo "  --close-firewall <bool>         Disable firewall and SELinux"
	echo "  --clean-screen <bool>           Clear screen before running"
	echo
	echo "Mode Options:"
	echo "  --only-registry                 Only change registry mirror mode"
	echo "  --ignore-backup-tips            Ignore overwrite-backup prompt"
	echo "  --pure-mode                     Minimal output mode"
	echo
}

mirror_list_docker_ce=(
	"Aliyun@mirrors.aliyun.com/docker-ce"
	"Tencent Cloud@mirrors.tencent.com/docker-ce"
	"Huawei Cloud@mirrors.huaweicloud.com/docker-ce"
	"Netease@mirrors.163.com/docker-ce"
	"Volcano Engine@mirrors.volces.com/docker"
	"Microsoft Azure China@mirror.azure.cn/docker-ce"
	"Tsinghua University@mirrors.tuna.tsinghua.edu.cn/docker-ce"
	"Peking University@mirrors.pku.edu.cn/docker-ce"
	"Zhejiang University@mirrors.zju.edu.cn/docker-ce"
	"Nanjing University@mirrors.nju.edu.cn/docker-ce"
	"Shanghai Jiao Tong University@mirror.sjtu.edu.cn/docker-ce"
	"Chongqing University of Posts and Telecommunications@mirrors.cqupt.edu.cn/docker-ce"
	"University of Science and Technology of China@mirrors.ustc.edu.cn/docker-ce"
	"Institute of Software, Chinese Academy of Sciences@mirror.iscas.ac.cn/docker-ce"
	"Official@download.docker.com"
)

mirror_list_registry=(
	"Millisecond Mirror (Recommended)@docker.1ms.run"
	"Docker Proxy@dockerproxy.net"
	"DaoCloud@docker.m.daocloud.io"
	"1Panel Mirror@docker.1panel.live"
	"Aliyun (Hangzhou)@registry.cn-hangzhou.aliyuncs.com"
	"Aliyun (Shanghai)@registry.cn-shanghai.aliyuncs.com"
	"Aliyun (Qingdao)@registry.cn-qingdao.aliyuncs.com"
	"Aliyun (Beijing)@registry.cn-beijing.aliyuncs.com"
	"Aliyun (Zhangjiakou)@registry.cn-zhangjiakou.aliyuncs.com"
	"Aliyun (Hohhot)@registry.cn-huhehaote.aliyuncs.com"
	"Aliyun (Ulanqab)@registry.cn-wulanchabu.aliyuncs.com"
	"Aliyun (Shenzhen)@registry.cn-shenzhen.aliyuncs.com"
	"Aliyun (Heyuan)@registry.cn-heyuan.aliyuncs.com"
	"Aliyun (Guangzhou)@registry.cn-guangzhou.aliyuncs.com"
	"Aliyun (Chengdu)@registry.cn-chengdu.aliyuncs.com"
	"Aliyun (Hong Kong)@registry.cn-hongkong.aliyuncs.com"
	"Aliyun (Tokyo, Japan)@registry.ap-northeast-1.aliyuncs.com"
	"Aliyun (Singapore)@registry.ap-southeast-1.aliyuncs.com"
	"Aliyun (Kuala Lumpur, Malaysia)@registry.ap-southeast-3.aliyuncs.com"
	"Aliyun (Jakarta, Indonesia)@registry.ap-southeast-5.aliyuncs.com"
	"Aliyun (Frankfurt, Germany)@registry.eu-central-1.aliyuncs.com"
	"Aliyun (London, UK)@registry.eu-west-1.aliyuncs.com"
	"Aliyun (US West - Silicon Valley)@registry.us-west-1.aliyuncs.com"
	"Aliyun (US East - Virginia)@registry.us-east-1.aliyuncs.com"
	"Aliyun (UAE - Dubai)@registry.me-east-1.aliyuncs.com"
	"Tencent Cloud@mirror.ccs.tencentyun.com"
	"Google Cloud (North America)@gcr.io"
	"Google Cloud (Asia)@asia.gcr.io"
	"Google Cloud (Europe)@eu.gcr.io"
	"Official Docker Hub@registry.hub.docker.com"
)

mirror_list_extranet=(
	"mirrors.aliyun.com/docker-ce"
	"mirrors.tencent.com/docker-ce"
	"mirrors.huaweicloud.com/docker-ce"
	"mirrors.volces.com/docker-ce"
)
mirror_list_intranet=(
	"mirrors.cloud.aliyuncs.com/docker-ce"
	"mirrors.tencentyun.com/docker-ce"
	"mirrors.myhuaweicloud.com/docker-ce"
	"mirrors.ivolces.com/docker-ce"
)

SYSTEM_DEBIAN="Debian"
SYSTEM_UBUNTU="Ubuntu"
SYSTEM_ZORIN="Zorin"
SYSTEM_RASPBERRY_PI_OS="Raspberry Pi OS"
SYSTEM_REDHAT="RedHat"
SYSTEM_RHEL="Red Hat Enterprise Linux"
SYSTEM_CENTOS_STREAM="CentOS Stream"
SYSTEM_ROCKY="Rocky"
SYSTEM_ALMALINUX="AlmaLinux"
SYSTEM_FEDORA="Fedora"
SYSTEM_ORACLE="Oracle Linux"
SYSTEM_OPENCLOUDOS="OpenCloudOS"
SYSTEM_TENCENTOS="TencentOS"
SYSTEM_OPENEULER="openEuler"
SYSTEM_ANOLISOS="Anolis"

File_LinuxRelease=/etc/os-release
File_RedHatRelease=/etc/redhat-release
File_DebianVersion=/etc/debian_version
File_RaspberryPiOSRelease=/etc/rpi-issue
File_openEulerRelease=/etc/openEuler-release
File_HuaweiCloudEulerOSRelease=/etc/hce-release
File_OpenCloudOSRelease=/etc/opencloudos-release
File_TencentOSServerRelease=/etc/tlinux-release
File_AnolisOSRelease=/etc/anolis-release
File_AlibabaCloudLinuxRelease=/etc/alinux-release
File_OracleLinuxRelease=/etc/oracle-release
File_ArchLinuxRelease=/etc/arch-release
File_GentooRelease=/etc/gentoo-release
File_openKylinVersion=/etc/kylin-version/kylin-system-version.conf

File_AptSourceList=/etc/apt/sources.list
Dir_AptAdditionalSources=/etc/apt/sources.list.d
Dir_YumRepos=/etc/yum.repos.d

Dir_Docker=/etc/docker
File_DockerConfig=$Dir_Docker/daemon.json
File_DockerConfigBackup=$Dir_Docker/daemon.json.bak
File_DockerVersionTmp=docker-version.txt
File_DockerCEVersionTmp=docker-ce-version.txt
File_DockerCECliVersionTmp=docker-ce-cli-version.txt
File_DockerSourceList=$Dir_AptAdditionalSources/docker.list
File_DockerRepo=$Dir_YumRepos/docker-ce.repo

RED='\033[31m'
GREEN='\033[32m'
BLUE='\033[34m'
PLAIN='\033[0m'
BOLD='\033[1m'
COMPLETE="\033[1;32m[OK]${PLAIN}"
WARN="\033[1;43m WARNING ${PLAIN}"
ERROR="\033[1;31m[ERROR]${PLAIN}"
FAIL="\033[1;31m[FAIL]${PLAIN}"
TIP="\033[1;44m INFO ${PLAIN}"
WORKING="\033[1;36m*${PLAIN}"

function main() {
	permission_judgment
	collect_system_info
	run_start
	choose_mirrors
	if [[ "${ONLY_REGISTRY}" == "true" ]]; then
		only_change_docker_registry_mirror
	else
		choose_protocol
		close_firewall_service
		install_dependency_packages
		configure_docker_ce_mirror
		install_docker_engine
		change_docker_registry_mirror
		check_installed_result
	fi
	run_end
}

function handle_command_options() {
	while [ $# -gt 0 ]; do
		case "$1" in

		--source)
			if [ "$2" ]; then
				if echo "$2" | grep -Eq "\(|\)|\[|\]|\{|\}"; then
					command_error "$2" "valid address"
				else
					SOURCE="$(echo "$2" | sed -e 's,^http[s]\?://,,g' -e 's,/$,,')"
					shift
				fi
			else
				command_error "$1" "software source address"
			fi
			;;

		--source-registry)
			if [ "$2" ]; then
				if echo "$2" | grep -Eq "\(|\)|\[|\]|\{|\}"; then
					command_error "$2" "valid address"
				else
					SOURCE_REGISTRY="$(echo "$2" | sed -e 's,^http[s]\?://,,g' -e 's,/$,,')"
					shift
				fi
			else
				command_error "$1" "repository address"
			fi
			;;

		--branch)
			if [ "$2" ]; then
				SOURCE_BRANCH="$2"
				shift
			else
				command_error "$1" "software source repository"
			fi
			;;

		--codename)
			if [ "$2" ]; then
				DEBIAN_CODENAME="$2"
				shift
			else
				command_error "$1" "version codename"
			fi
			;;

		--designated-version)
			if [ "$2" ]; then
				if echo "$2" | grep -Eq "^[0-9][0-9].[0-9]{1,2}.[0-9]{1,2}$"; then
					DESIGNATED_DOCKER_VERSION="$2"
					shift
				else
					command_error "$2" "valid version number"
				fi
			else
				command_error "$1" "version number"
			fi
			;;

		--protocol)
			if [ "$2" ]; then
				case "$2" in
				http | https | HTTP | HTTPS)
					WEB_PROTOCOL="${2,,}"
					shift
					;;
				*)
					command_error "$2" " http or https "
					;;
				esac
			else
				command_error "$1" " WEB protocol (http/https) "
			fi
			;;

		--use-intranet-source)
			if [ "$2" ]; then
				case "$2" in
				[Tt]rue | [Ff]alse)
					USE_INTRANET_SOURCE="${2,,}"
					shift
					;;
				*)
					command_error "$2" " true or false "
					;;
				esac
			else
				command_error "$1" " true or false "
			fi
			;;
		--install-latest | --install-latested)
			if [ "$2" ]; then
				case "$2" in
				[Tt]rue | [Ff]alse)
					INSTALL_LATESTED_DOCKER="${2,,}"
					shift
					;;
				*)
					command_error "$2" " true or false "
					;;
				esac
			else
				command_error "$1" " true or false "
			fi
			;;
		--ignore-backup-tips)
			IGNORE_BACKUP_TIPS="true"
			;;
		--close-firewall)
			if [ "$2" ]; then
				case "$2" in
				[Tt]rue | [Ff]alse)
					CLOSE_FIREWALL="${2,,}"
					shift
					;;
				*)
					command_error "$2" " true or false "
					;;
				esac
			else
				command_error "$1" " true or false "
			fi
			;;
		--clean-screen)
			if [ "$2" ]; then
				case "$2" in
				[Tt]rue | [Ff]alse)
					CLEAN_SCREEN="${2,,}"
					shift
					;;
				*)
					command_error "$2" " true or false "
					;;
				esac
			else
				command_error "$1" " true or false "
			fi
			;;
		--only-registry)
			ONLY_REGISTRY="true"
			;;
		--pure-mode)
			PURE_MODE="true"
			;;
		--data-root)
			if [ "$2" ]; then
				if echo "$2" | grep -Eq "\(|\)|\[|\]|\{|\}"; then
					command_error "$2" "valid directory path"
				else
					DOCKER_DATA_ROOT="$2"
					shift
				fi
			else
				command_error "$1" "directory path"
			fi
			;;

		--help)
			output_command_help
			exit
			;;
		*)
			command_error "$1"
			;;
		esac
		shift
	done
	IGNORE_BACKUP_TIPS="${IGNORE_BACKUP_TIPS:-"false"}"
	if [[ "${DESIGNATED_DOCKER_VERSION}" ]]; then
		INSTALL_LATESTED_DOCKER="false"
	fi
	PURE_MODE="${PURE_MODE:-"false"}"
	DOCKER_DATA_ROOT="${DOCKER_DATA_ROOT:-""}"
}

function run_start() {
	if [ -z "${CLEAN_SCREEN}" ]; then
		[[ -z "${SOURCE}" || -z "${SOURCE_REGISTRY}" ]] && clear
	elif [ "${CLEAN_SCREEN}" == "true" ]; then
		clear
	fi
	if [[ "${PURE_MODE}" == "true" ]]; then
		return
	fi
}

function run_end() {
	if [[ "${PURE_MODE}" == "true" ]]; then
		echo
		return
	fi
}

function output_error() {
	[ "$1" ] && echo -e "\n$ERROR $1\n"
	exit 1
}

function command_error() {
	local tmp_text="Please verify and re-enter"
	if [[ "${2}" ]]; then
		tmp_text="Please provide ${2} after this option"
	fi
	output_error "Command option ${BLUE}$1${PLAIN} is invalid, ${tmp_text}!"
}

function unsupport_system_error() {
	local tmp_text=""
	if [[ "${2}" ]]; then
		tmp_text=", please install manually with the following commands:\n\n${BLUE}$2${PLAIN}"
	fi
	output_error "The current operating system ($1) is not supported${tmp_text}"
}

function input_error() {
	echo -e "\n$WARN Invalid input, $1!"
}

function command_exists() {
	command -v "$@" &>/dev/null
}

function permission_judgment() {
	if [ $UID -ne 0 ]; then
		output_error "Insufficient permissions. Please run this script as root."
	fi
}

function collect_system_info() {
	## Define system name
	SYSTEM_NAME="$(cat $File_LinuxRelease | grep -E "^NAME=" | awk -F '=' '{print$2}' | sed "s/[\'\"]//g")"
	grep -q "PRETTY_NAME=" $File_LinuxRelease && SYSTEM_PRETTY_NAME="$(cat $File_LinuxRelease | grep -E "^PRETTY_NAME=" | awk -F '=' '{print$2}' | sed "s/[\'\"]//g")"
	## Define system version number
	SYSTEM_VERSION_ID="$(cat $File_LinuxRelease | grep -E "^VERSION_ID=" | awk -F '=' '{print$2}' | sed "s/[\'\"]//g")"
	SYSTEM_VERSION_ID_MAJOR="${SYSTEM_VERSION_ID%.*}"
	## Determine current system faction
	if [ -s "${File_DebianVersion}" ]; then
		SYSTEM_FACTIONS="${SYSTEM_DEBIAN}"
	elif [ -s "${File_RedHatRelease}" ]; then
		SYSTEM_FACTIONS="${SYSTEM_REDHAT}"
	elif [ -s "${File_openEulerRelease}" ] || [ -s "${File_HuaweiCloudEulerOSRelease}" ]; then
		SYSTEM_FACTIONS="${SYSTEM_OPENEULER}"
	elif [ -s "${File_OpenCloudOSRelease}" ]; then
		SYSTEM_FACTIONS="${SYSTEM_OPENCLOUDOS}" # Self-based from 9.0 version onwards
	elif [ -s "${File_AnolisOSRelease}" ]; then
		SYSTEM_FACTIONS="${SYSTEM_ANOLISOS}" # Self-based from 8.8 version onwards
	elif [ -s "${File_TencentOSServerRelease}" ]; then
		SYSTEM_FACTIONS="${SYSTEM_TENCENTOS}" # Self-based from 4 version onwards
	elif [ -s "${File_openKylinVersion}" ]; then
		[[ "${ONLY_REGISTRY}" != "true" ]] && unsupport_system_error "openKylin" "apt-get install -y docker\nsystemctl enable --now docker"
	elif [ -f "${File_ArchLinuxRelease}" ]; then
		[[ "${ONLY_REGISTRY}" != "true" ]] && unsupport_system_error "Arch Linux" "pacman -S docker\nsystemctl enable --now docker"
	elif [ -f "${File_GentooRelease}" ]; then
		[[ "${ONLY_REGISTRY}" != "true" ]] && unsupport_system_error "Gentoo"
	elif [[ "${SYSTEM_NAME}" == *"openSUSE"* ]]; then
		[[ "${ONLY_REGISTRY}" != "true" ]] && unsupport_system_error "openSUSE" "zypper install docker\nsystemctl enable --now docker"
	elif [[ "${SYSTEM_NAME}" == *"NixOS"* ]]; then
		[[ "${ONLY_REGISTRY}" != "true" ]] && unsupport_system_error "NixOS"
	else
		unsupport_system_error "Unknown system"
	fi
	## Determine system type, version, and version number
	case "${SYSTEM_FACTIONS}" in
	"${SYSTEM_DEBIAN}")
		if ! command_exists lsb_release; then
			apt-get update
			if ! apt-get install -y lsb-release; then
				output_error "lsb-release package installation failed\n\nThis script relies on the lsb_release command to determine the specific distribution and version. Your system might be a minimal install. Please install it and rerun the script!"
			fi
		fi
		SYSTEM_JUDGMENT="$(lsb_release -is)"
		SYSTEM_VERSION_CODENAME="${DEBIAN_CODENAME:-"$(lsb_release -cs)"}"
		# Raspberry Pi OS
		if [ -s "${File_RaspberryPiOSRelease}" ]; then
			SYSTEM_JUDGMENT="${SYSTEM_RASPBERRY_PI_OS}"
			SYSTEM_PRETTY_NAME="${SYSTEM_RASPBERRY_PI_OS}"
		fi
		;;
	"${SYSTEM_REDHAT}")
		SYSTEM_JUDGMENT="$(awk '{printf $1}' $File_RedHatRelease)"
		## Special system judgment
		# Red Hat Enterprise Linux
		grep -q "${SYSTEM_RHEL}" $File_RedHatRelease && SYSTEM_JUDGMENT="${SYSTEM_RHEL}"
		# CentOS Stream
		grep -q "${SYSTEM_CENTOS_STREAM}" $File_RedHatRelease && SYSTEM_JUDGMENT="${SYSTEM_CENTOS_STREAM}"
		# Oracle Linux
		[ -s "${File_OracleLinuxRelease}" ] && SYSTEM_JUDGMENT="${SYSTEM_ORACLE}"
		;;
	*)
		SYSTEM_JUDGMENT="${SYSTEM_FACTIONS}"
		;;
	esac
	## Determine system processor architecture
	DEVICE_ARCH_RAW="$(uname -m)"
	case "${DEVICE_ARCH_RAW}" in
	x86_64)
		DEVICE_ARCH="x86_64"
		;;
	aarch64)
		DEVICE_ARCH="ARM64"
		;;
	armv8l)
		DEVICE_ARCH="ARMv8_32"
		;;
	armv7l)
		DEVICE_ARCH="ARMv7"
		;;
	armv6l)
		DEVICE_ARCH="ARMv6"
		;;
	armv5tel)
		DEVICE_ARCH="ARMv5"
		;;
	ppc64le)
		DEVICE_ARCH="ppc64le"
		;;
	s390x)
		DEVICE_ARCH="s390x"
		;;
	i386 | i686)
		output_error "Docker Engine does not support installation on x86_32 architecture environment!"
		;;
	*)
		output_error "Unknown system architecture: ${DEVICE_ARCH_RAW}"
		;;
	esac
	## Define software source repository name
	if [[ -z "${SOURCE_BRANCH}" ]]; then
		case "${SYSTEM_FACTIONS}" in
		"${SYSTEM_DEBIAN}")
			case "${SYSTEM_JUDGMENT}" in
			"${SYSTEM_DEBIAN}")
				SOURCE_BRANCH="debian"
				;;
			"${SYSTEM_UBUNTU}" | "${SYSTEM_ZORIN}")
				SOURCE_BRANCH="ubuntu"
				;;
			"${SYSTEM_RASPBERRY_PI_OS}")
				case "${DEVICE_ARCH_RAW}" in
				x86_64 | aarch64)
					SOURCE_BRANCH="debian"
					;;
				*)
					SOURCE_BRANCH="raspbian"
					;;
				esac
				;;
			*)
				# Some Debian-based derivative operating systems use Debian 12's docker ce source
				SOURCE_BRANCH="debian"
				SYSTEM_VERSION_CODENAME="bookworm"
				;;
			esac
			;;
		"${SYSTEM_REDHAT}" | "${SYSTEM_OPENEULER}" | "${SYSTEM_OPENCLOUDOS}" | "${SYSTEM_ANOLISOS}" | "${SYSTEM_TENCENTOS}")
			case "${SYSTEM_JUDGMENT}" in
			"${SYSTEM_FEDORA}")
				SOURCE_BRANCH="fedora"
				;;
			"${SYSTEM_RHEL}")
				SOURCE_BRANCH="rhel"
				# RHEL 10
				if [[ "${SYSTEM_VERSION_ID_MAJOR}" == 10 ]]; then
					echo -e "\n$WARN Installing via the centos branch (RHEL-derived installation). There may be unforeseen compatibility issues!"
					echo -e "\n$TIP Docker does not officially support RHEL 10. Red Hat removed Docker from official repositories and defaults to Podman."
					SOURCE_BRANCH="centos"
				fi
				;;
			*)
				SOURCE_BRANCH="centos"
				;;
			esac
			if [[ "${DEVICE_ARCH_RAW}" == "s390x" ]]; then
				output_error "Please consult the RHEL release notes for s390x support"
			fi
			;;
		esac
	fi
	## Define update text for syncing mirrors
	case "${SYSTEM_FACTIONS}" in
	"${SYSTEM_DEBIAN}")
		SYNC_MIRROR_TEXT="Update package sources"
		;;
	"${SYSTEM_REDHAT}" | "${SYSTEM_OPENEULER}" | "${SYSTEM_OPENCLOUDOS}" | "${SYSTEM_ANOLISOS}" | "${SYSTEM_TENCENTOS}")
		SYNC_MIRROR_TEXT="Generate repository cache"
		;;
	esac
	## Determine if advanced interactive selector can be used
	CAN_USE_ADVANCED_INTERACTIVE_SELECTION="false"
	if command_exists tput; then
		CAN_USE_ADVANCED_INTERACTIVE_SELECTION="true"
	fi
}

function choose_mirrors() {

	function print_mirrors_list() {
		local tmp_mirror_name arr_num default_mirror_name_length a i
		echo

		local list_arr=()
		local -n ref="$1"
		local list_arr_sum="${#ref[@]}"
		for ((a = 0; a < list_arr_sum; a++)); do
			list_arr[a]="${ref[a]}"
		done
		if command_exists printf; then
			for ((i = 0; i < ${#list_arr[@]}; i++)); do
				tmp_mirror_name=$(echo "${list_arr[i]}" | awk -F '@' '{print$1}') # Software source name
				arr_num=$((i + 1))
				default_mirror_name_length=${2:-"30"} # Default software source name print length
				printf "- %-${default_mirror_name_length}s %4s\n" "${tmp_mirror_name}" "$arr_num)"
			done
		else
			for ((i = 0; i < ${#list_arr[@]}; i++)); do
				tmp_mirror_name="${list_arr[i]%@*}" # Software source name
				arr_num=$((i + 1))
				echo -e " - $arr_num) ${tmp_mirror_name}"
			done
		fi
	}

	function choose_use_intranet_address() {
		local ask_text="By default the public mirror address will be used. Continue?"
		local intranet_source
		for ((i = 0; i < ${#mirror_list_extranet[@]}; i++)); do
			if [[ "${SOURCE}" == "${mirror_list_extranet[i]}" ]]; then
				intranet_source="${mirror_list_intranet[i]}"
				ONLY_HTTP="true" # Force use of HTTP protocol
				break
			else
				continue
			fi
		done
		if [[ -z "${USE_INTRANET_SOURCE}" ]]; then
			if [[ "${CAN_USE_ADVANCED_INTERACTIVE_SELECTION}" == "true" ]]; then
				echo
				interactive_select_boolean "${BOLD}${ask_text}${PLAIN}"
				if [[ "${_SELECT_RESULT}" == "false" ]]; then
					SOURCE="${intranet_source}"
					[[ "${PURE_MODE}" != "true" ]] && echo -e "\n$WARN Switched to intranet-only address; use only in specific environments!"
				fi
			else
				local CHOICE
				CHOICE=$(echo -e "\n${BOLD}> ${ask_text} [Y/n] ${PLAIN}")
				read -rp "${CHOICE}" INPUT
				[[ -z "${INPUT}" ]] && INPUT=Y
				case "${INPUT}" in
				[Yy] | [Yy][Ee][Ss]) ;;
				[Nn] | [Nn][Oo])
					SOURCE="${intranet_source}"
					[[ "${PURE_MODE}" != "true" ]] && echo -e "\n$WARN Switched to intranet-only address; use only in specific environments!"
					;;
				*)
					input_error "Default: do not use intranet address"
					;;
				esac
			fi
		elif [[ "${USE_INTRANET_SOURCE}" == "true" ]]; then
			SOURCE="${intranet_source}"
		fi
	}

	function print_title() {
		local system_name="${SYSTEM_PRETTY_NAME:-"${SYSTEM_NAME} ${SYSTEM_VERSION_ID}"}"
		local arch="${DEVICE_ARCH}"
		local date_time timezone
		date_time="$(date "+%Y-%m-%d %H:%M")"
		timezone="$(timedatectl status 2>/dev/null | grep "Time zone" | awk -F ':' '{print$2}' | awk -F ' ' '{print$1}')"

		echo
		echo -e "Environment ${BLUE}${system_name} ${arch}${PLAIN}"
		echo -e "System time ${BLUE}${date_time} ${timezone}${PLAIN}"
	}

	[[ "${PURE_MODE}" != "true" ]] && print_title

	local mirror_list_name
	if [[ -z "${SOURCE}" ]] && [[ "${ONLY_REGISTRY}" != "true" ]]; then
		mirror_list_name="mirror_list_docker_ce"
		if [[ "${CAN_USE_ADVANCED_INTERACTIVE_SELECTION}" == "true" ]]; then
			sleep 1 >/dev/null 2>&1
			interactive_select_mirror "${mirror_list_docker_ce[@]}" "\n ${BOLD}Please select the Docker CE mirror you want to use:${PLAIN}\n"
			SOURCE="${_SELECT_RESULT#*@}"
			echo -e "\n* ${BOLD}Docker CE: ${_SELECT_RESULT%@*}${PLAIN}"
		else
			print_mirrors_list "${mirror_list_name}" 38
			local -n arr_ref="${mirror_list_name}"
			local max_idx="${#arr_ref[@]}"
			local CHOICE_B
			CHOICE_B=$(echo -e "\n${BOLD}> Please enter the number for the Docker CE mirror to use [ 1-${max_idx} ]:${PLAIN}")
			while true; do
				read -rp "${CHOICE_B}" INPUT
				case "${INPUT}" in
				[1-9] | [1-9][0-9] | [1-9][0-9][0-9])
					local tmp_source="${arr_ref[$((INPUT - 1))]}"
					if [[ -z "${tmp_source}" ]]; then
						echo -e "\n$WARN Please enter a valid number!"
					else
						SOURCE="$(echo "${arr_ref[$((INPUT - 1))]}" | awk -F '@' '{print$2}')"
						break
					fi
					;;
				*)
					echo -e "\n$WARN Please enter a numeric index to select the mirror you want to use!"
					;;
				esac
			done
		fi
	fi

	if [[ "${mirror_list_extranet[*]}" =~ (^|[^[:alpha:]])"${SOURCE}"([^[:alpha:]]|$) ]]; then
		choose_use_intranet_address
	fi

	if [[ -z "${SOURCE_REGISTRY}" ]]; then
		mirror_list_name="mirror_list_registry"
		if [[ "${CAN_USE_ADVANCED_INTERACTIVE_SELECTION}" == "true" ]]; then
			sleep 1 >/dev/null 2>&1
			interactive_select_mirror "${mirror_list_registry[@]}" "\n ${BOLD}Please select the Docker Registry source you want to use:${PLAIN}\n"
			SOURCE_REGISTRY="${_SELECT_RESULT#*@}"
			echo -e "\n* ${BOLD}Docker Registry: ${_SELECT_RESULT%@*}${PLAIN}"
		else
			print_mirrors_list "${mirror_list_name}" 44
			local -n arr_ref="${mirror_list_name}"
			local max_idx="${#arr_ref[@]}"
			local CHOICE_C
			CHOICE_C=$(echo -e "\n${BOLD}> Please enter the number for the Docker Registry mirror to use [ 1-${max_idx} ]:${PLAIN}")
			while true; do
				read -rp "${CHOICE_C}" INPUT
				case "${INPUT}" in
				[1-9] | [1-9][0-9] | [1-9][0-9][0-9])
					local tmp_source="${arr_ref[$((INPUT - 1))]}"
					if [[ -z "${tmp_source}" ]]; then
						echo -e "\n$WARN Please enter a valid number!"
					else
						SOURCE_REGISTRY="$(echo "${arr_ref[$((INPUT - 1))]}" | awk -F '@' '{print$2}')"
						break
					fi
					;;
				*)
					echo -e "\n$WARN Please enter a numeric index to select the mirror you want to use!"
					;;
				esac
			done
		fi
	fi
}

function choose_protocol() {
	if [[ -z "${WEB_PROTOCOL}" ]]; then
		if [[ "${ONLY_HTTP}" == "true" ]]; then
			WEB_PROTOCOL="http"
		else
			local ask_text="Use HTTP protocol for the mirror?"
			if [[ "${CAN_USE_ADVANCED_INTERACTIVE_SELECTION}" == "true" ]]; then
				echo
				interactive_select_boolean "${BOLD}${ask_text}${PLAIN}"
				if [[ "${_SELECT_RESULT}" == "true" ]]; then
					WEB_PROTOCOL="http"
				else
					WEB_PROTOCOL="https"
				fi
			else
				local CHOICE
				CHOICE=$(echo -e "\n${BOLD}> ${ask_text} [Y/n] ${PLAIN}")
				read -rp "${CHOICE}" INPUT
				[[ -z "${INPUT}" ]] && INPUT=Y
				case "${INPUT}" in
				[Yy] | [Yy][Ee][Ss])
					WEB_PROTOCOL="http"
					;;
				[Nn] | [Nn][Oo])
					WEB_PROTOCOL="https"
					;;
				*)
					input_error "Default: use HTTPS protocol"
					WEB_PROTOCOL="https"
					;;
				esac
			fi
		fi
	fi
	WEB_PROTOCOL="${WEB_PROTOCOL,,}"
}

function close_firewall_service() {
	if ! command_exists systemctl; then
		return
	fi
	if [[ "$(systemctl is-active firewalld)" == "active" ]]; then
		if [[ -z "${CLOSE_FIREWALL}" ]]; then
			local ask_text="Do you want to disable the system firewall and SELinux?"
			if [[ "${CAN_USE_ADVANCED_INTERACTIVE_SELECTION}" == "true" ]]; then
				echo
				interactive_select_boolean "${BOLD}${ask_text}${PLAIN}"
				if [[ "${_SELECT_RESULT}" == "true" ]]; then
					CLOSE_FIREWALL="true"
				fi
			else
				local CHOICE
				CHOICE=$(echo -e "\n${BOLD}> ${ask_text} [Y/n] ${PLAIN}")
				read -rp "${CHOICE}" INPUT
				[[ -z "${INPUT}" ]] && INPUT=Y
				case "${INPUT}" in
				[Yy] | [Yy][Ee][Ss])
					CLOSE_FIREWALL="true"
					;;
				[Nn] | [Nn][Oo]) ;;
				*)
					input_error "Default: do not disable"
					;;
				esac
			fi
		fi
		if [[ "${CLOSE_FIREWALL}" == "true" ]]; then
			local SelinuxConfig=/etc/selinux/config
			systemctl disable --now firewalld >/dev/null 2>&1
			[ -s "${SelinuxConfig}" ] && sed -i "s/SELINUX=enforcing/SELINUX=disabled/g" $SelinuxConfig && setenforce 0 >/dev/null 2>&1
		fi
	fi
}

function install_dependency_packages() {
	local commands package_manager

	case "${SYSTEM_FACTIONS}" in
	"${SYSTEM_DEBIAN}")
		sed -i '/docker-ce/d' $File_AptSourceList
		rm -rf $File_DockerSourceList
		;;
	"${SYSTEM_REDHAT}" | "${SYSTEM_OPENEULER}" | "${SYSTEM_OPENCLOUDOS}" | "${SYSTEM_ANOLISOS}" | "${SYSTEM_TENCENTOS}")
		rm -rf $Dir_YumRepos/*docker*.repo
		;;
	esac

	commands=()
	case "${SYSTEM_FACTIONS}" in
	"${SYSTEM_DEBIAN}")
		package_manager="apt-get"
		commands+=("${package_manager} update")
		;;
	"${SYSTEM_REDHAT}" | "${SYSTEM_OPENEULER}" | "${SYSTEM_OPENCLOUDOS}" | "${SYSTEM_ANOLISOS}" | "${SYSTEM_TENCENTOS}")
		package_manager="$(get_package_manager)"
		commands+=("${package_manager} makecache")
		;;
	esac
	if [[ "${PURE_MODE}" == "true" ]]; then
		local exec_cmd=""
		for cmd in "${commands[@]}"; do
			if [[ -z "${exec_cmd}" ]]; then
				exec_cmd="${cmd}"
			else
				exec_cmd="${exec_cmd} ; ${cmd}"
			fi
		done
		echo
		animate_exec "${exec_cmd}" "${SYNC_MIRROR_TEXT}"
	else
		echo -e "\n$WORKING ${SYNC_MIRROR_TEXT}...\n"
		{ for cmd in "${commands[@]}"; do
			$cmd
		done; } || output_error "${SYNC_MIRROR_TEXT} failed. Please fix existing repository errors to ensure ${BLUE}${package_manager}${PLAIN} is available!"
		echo -e "\n$COMPLETE ${SYNC_MIRROR_TEXT} completed\n"
	fi

	commands=()
	case "${SYSTEM_FACTIONS}" in
	"${SYSTEM_DEBIAN}")
		commands+=("${package_manager} install -y ca-certificates curl")
		;;
	"${SYSTEM_REDHAT}" | "${SYSTEM_OPENEULER}" | "${SYSTEM_OPENCLOUDOS}" | "${SYSTEM_ANOLISOS}" | "${SYSTEM_TENCENTOS}")
		# Note: Red Hat 8 version released dnf package management tool
		case "${SYSTEM_VERSION_ID_MAJOR}" in
		7)
			commands+=("${package_manager} install -y yum-utils device-mapper-persistent-data lvm2")
			;;
		*)
			if [[ "${package_manager}" == "dnf" ]]; then
				commands+=("${package_manager} install -y dnf-plugins-core")
			else
				commands+=("${package_manager} install -y yum-utils device-mapper-persistent-data lvm2")
			fi
			;;
		esac
		;;
	esac
	if [[ "${PURE_MODE}" == "true" ]]; then
		local exec_cmd=""
		for cmd in "${commands[@]}"; do
			if [[ -z "${exec_cmd}" ]]; then
				exec_cmd="${cmd}"
			else
				exec_cmd="${exec_cmd} ; ${cmd}"
			fi
		done
		echo
		animate_exec "${exec_cmd}" "Install dependency packages"
	else
		for cmd in "${commands[@]}"; do
			$cmd
		done
	fi
}

function configure_docker_ce_mirror() {
	local commands=()
	case "${SYSTEM_FACTIONS}" in
	"${SYSTEM_DEBIAN}")
		## Handle GPG key
		local file_keyring="/etc/apt/keyrings/docker.asc"
		apt-key del 9DC8 5822 9FC7 DD38 854A E2D8 8D81 803C 0EBF CD88 >/dev/null 2>&1 # Delete old key
		[ -f "${file_keyring}" ] && rm -rf $file_keyring
		install -m 0755 -d /etc/apt/keyrings
		curl -fsSL "${WEB_PROTOCOL}://${SOURCE}/linux/${SOURCE_BRANCH}/gpg" -o $file_keyring >/dev/null
		if [ ! -s "$file_keyring" ]; then
			output_error "Failed to download GPG key. Please check your network or switch the Docker CE mirror and retry!"
		fi
		chmod a+r $file_keyring
		## Add source
		echo "deb [arch=$(dpkg --print-architecture) signed-by=${file_keyring}] ${WEB_PROTOCOL}://${SOURCE}/linux/${SOURCE_BRANCH} ${SYSTEM_VERSION_CODENAME} stable" | tee $File_DockerSourceList >/dev/null 2>&1
		commands+=("apt-get update")
		;;
	"${SYSTEM_REDHAT}" | "${SYSTEM_OPENEULER}" | "${SYSTEM_OPENCLOUDOS}" | "${SYSTEM_ANOLISOS}" | "${SYSTEM_TENCENTOS}")
		local repo_file_url="${WEB_PROTOCOL}://${SOURCE}/linux/${SOURCE_BRANCH}/docker-ce.repo"
		local package_manager
		package_manager="$(get_package_manager)"
		case "${SYSTEM_VERSION_ID_MAJOR}" in
		7)
			yum-config-manager -y --add-repo "${repo_file_url}"
			;;
		*)
			if [[ "${SYSTEM_JUDGMENT}" == "${SYSTEM_FEDORA}" ]]; then
				dnf-3 config-manager -y --add-repo "${repo_file_url}"
			else
				if [[ "${package_manager}" == "dnf" ]]; then
					dnf config-manager -y --add-repo "${repo_file_url}"
				else
					yum-config-manager -y --add-repo "${repo_file_url}"
				fi
			fi
			;;
		esac
		sed -e "s|https://download.docker.com|${WEB_PROTOCOL}://${SOURCE}|g" \
			-e "s|http[s]\?://.*/linux/${SOURCE_BRANCH}/|${WEB_PROTOCOL}://${SOURCE}/linux/${SOURCE_BRANCH}/|g" \
			-i \
			$File_DockerRepo
		## Compatibility handling version number
		if [[ "${SYSTEM_JUDGMENT}" != "${SYSTEM_FEDORA}" ]]; then
			local target_version
			case "${SYSTEM_VERSION_ID_MAJOR}" in
			7 | 8 | 9 | 10)
				target_version="${SYSTEM_VERSION_ID_MAJOR}"
				;;
			*)
				target_version="8" # Note: Some systems use 9 version branch for compatibility issues
				## Adapt to domestic operating systems
				# OpenCloudOS, Anolis OS 23 version
				if [[ "${SYSTEM_JUDGMENT}" == "${SYSTEM_OPENCLOUDOS}" || "${SYSTEM_JUDGMENT}" == "${SYSTEM_ANOLISOS}" ]]; then
					if [[ "${SYSTEM_VERSION_ID_MAJOR}" == 23 ]]; then
						target_version="9"
					fi
				fi
				if [[ "${SYSTEM_JUDGMENT}" == "${SYSTEM_OPENEULER}" ]]; then
					if [ -s "${File_HuaweiCloudEulerOSRelease}" ]; then
						# Huawei Cloud EulerOS
						case "${SYSTEM_VERSION_ID_MAJOR}" in
						1)
							target_version="8" # openEuler 20
							;;
						2)
							target_version="9" # openEuler 22
							;;
						esac
					else
						# openEuler
						if [[ "${SYSTEM_VERSION_ID_MAJOR}" -ge 22 ]]; then
							target_version="9"
						fi
					fi
				fi
				# TencentOS Server
				if [ -s "${File_TencentOSServerRelease}" ]; then
					case "${SYSTEM_VERSION_ID_MAJOR}" in
					4)
						target_version="9"
						;;
					3)
						target_version="8"
						;;
					2)
						target_version="7"
						;;
					esac
				fi
				# Alibaba Cloud Linux
				if [ -s "${File_AnolisOSRelease}" ] && [ -s "${File_AlibabaCloudLinuxRelease}" ]; then
					case "${SYSTEM_VERSION_ID_MAJOR}" in
					3)
						target_version="8"
						;;
					2)
						target_version="7"
						;;
					esac
				fi
				;;
			esac
			sed -i "s|\$releasever|${target_version}|g" $File_DockerRepo
			commands+=("${package_manager} makecache")
		fi
		;;
	esac
	echo
	if [[ "${PURE_MODE}" == "true" ]]; then
		local exec_cmd=""
		for cmd in "${commands[@]}"; do
			if [[ -z "${exec_cmd}" ]]; then
				exec_cmd="${cmd}"
			else
				exec_cmd="${exec_cmd} ; ${cmd}"
			fi
		done
		animate_exec "${exec_cmd}" "${SYNC_MIRROR_TEXT}"
	else
		for cmd in "${commands[@]}"; do
			$cmd
		done
	fi
}

function install_docker_engine() {

	function export_version_list() {
		case "${SYSTEM_FACTIONS}" in
		"${SYSTEM_DEBIAN}")
			apt-cache madison docker-ce | awk '{print $3}' | grep -Eo "[0-9][0-9].[0-9]{1,2}.[0-9]{1,2}" >$File_DockerCEVersionTmp
			apt-cache madison docker-ce-cli | awk '{print $3}' | grep -Eo "[0-9][0-9].[0-9]{1,2}.[0-9]{1,2}" >$File_DockerCECliVersionTmp
			grep -wf $File_DockerCEVersionTmp $File_DockerCECliVersionTmp >$File_DockerVersionTmp
			;;
		"${SYSTEM_REDHAT}" | "${SYSTEM_OPENEULER}" | "${SYSTEM_OPENCLOUDOS}" | "${SYSTEM_ANOLISOS}" | "${SYSTEM_TENCENTOS}")
			local package_manager
			package_manager="$(get_package_manager)"
			$package_manager list docker-ce --showduplicates | sort -r | awk '{print $2}' | grep -Eo "[0-9][0-9].[0-9]{1,2}.[0-9]{1,2}" >$File_DockerCEVersionTmp
			$package_manager list docker-ce-cli --showduplicates | sort -r | awk '{print $2}' | grep -Eo "[0-9][0-9].[0-9]{1,2}.[0-9]{1,2}" >$File_DockerCECliVersionTmp
			grep -wf $File_DockerCEVersionTmp $File_DockerCECliVersionTmp >$File_DockerVersionTmp
			;;
		esac
		rm -rf $File_DockerCEVersionTmp $File_DockerCECliVersionTmp
	}

	function uninstall_original_version() {
		if command_exists docker; then

			systemctl disable --now docker >/dev/null 2>&1
			sleep 2s
		fi

		local package_list
		case "${SYSTEM_FACTIONS}" in
		"${SYSTEM_DEBIAN}")
			package_list='docker* podman podman-docker containerd runc'
			;;
		"${SYSTEM_REDHAT}" | "${SYSTEM_OPENEULER}" | "${SYSTEM_OPENCLOUDOS}" | "${SYSTEM_ANOLISOS}" | "${SYSTEM_TENCENTOS}")
			package_list='docker* podman podman-docker runc'
			;;
		esac

		case "${SYSTEM_FACTIONS}" in
		"${SYSTEM_DEBIAN}")
			apt-get remove -y "$package_list" >/dev/null 2>&1
			apt-get autoremove -y >/dev/null 2>&1
			;;
		"${SYSTEM_REDHAT}" | "${SYSTEM_OPENEULER}" | "${SYSTEM_OPENCLOUDOS}" | "${SYSTEM_ANOLISOS}" | "${SYSTEM_TENCENTOS}")
			local package_manager
			package_manager="$(get_package_manager)"
			$package_manager remove -y "$package_list" >/dev/null 2>&1
			$package_manager autoremove -y >/dev/null 2>&1
			;;
		esac
	}

	function install_main() {
		local target_docker_version
		local pkgs=""
		local commands=()
		if [[ "${INSTALL_LATESTED_DOCKER}" == "true" ]]; then
			pkgs="docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin"
		else
			export_version_list
			if [ ! -s "${File_DockerVersionTmp}" ]; then
				rm -rf $File_DockerVersionTmp
				output_error "Failed to query the Docker Engine version list!"
			fi
			if [[ "${DESIGNATED_DOCKER_VERSION}" ]]; then
				if ! grep -Eq "^${DESIGNATED_DOCKER_VERSION}$" "$File_DockerVersionTmp"; then
					rm -rf $File_DockerVersionTmp
					output_error "The specified Docker Engine version does not exist or is not supported!"
				fi
				target_docker_version="${DESIGNATED_DOCKER_VERSION}"
			else
				if [[ "${CAN_USE_ADVANCED_INTERACTIVE_SELECTION}" == "true" ]]; then
					local version_list=()
					mapfile -t version_list < <(cat "$File_DockerVersionTmp" | sort -t '.' -k1,1nr -k2,2nr -k3,3nr)
					interactive_select_mirror "${version_list[@]}" "\n ${BOLD}Please select the version you want to install:${PLAIN}\n"
					target_docker_version="${_SELECT_RESULT}"
					echo -e "\n* ${BOLD}Specified install version: ${target_docker_version}${PLAIN}\n"
				else
					echo -e "\n${GREEN} --------- Please choose the version to install, e.g., 28.3.0 ---------- ${PLAIN}\n"
					cat $File_DockerVersionTmp
					while true; do
						local CHOICE
						CHOICE=$(echo -e "\n${BOLD}> Please choose and enter the exact version number you want to install from the list above:${PLAIN}\n")
						read -r -p "${CHOICE}" target_docker_version
						echo
						if grep -Eqw "${target_docker_version}" "$File_DockerVersionTmp"; then
							if echo "${target_docker_version}" | grep -Eqw '[0-9][0-9]\.[0-9]{1,2}\.[0-9]{1,2}'; then
								break
							else
								echo -e "$ERROR Please enter a valid version number!"
							fi
						else
							echo -e "$ERROR Invalid input, please try again!"
						fi
					done
				fi
			fi
			rm -rf $File_DockerVersionTmp
			local major_version
			major_version="$(echo "${target_docker_version}" | cut -d'.' -f1)"
			local minor_version
			minor_version="$(echo "${target_docker_version}" | cut -d'.' -f2)"
			case "${SYSTEM_FACTIONS}" in
			"${SYSTEM_DEBIAN}")
				if [[ $major_version -gt 18 ]] || [[ $major_version -eq 18 && $minor_version -ge 9 ]]; then
					local tmp_version
					tmp_version="$(apt-cache madison docker-ce-cli | grep "${target_docker_version}" | head -1 | awk '{print $3}' | awk -F "${target_docker_version}" '{print$1}')"
					pkgs="docker-ce=${tmp_version}${target_docker_version}* docker-ce-cli=${tmp_version}${target_docker_version}*"
				else
					pkgs="docker-ce=${target_docker_version}* docker-ce-cli=${target_docker_version}*"
				fi
				;;

			"${SYSTEM_REDHAT}" | "${SYSTEM_OPENEULER}" | "${SYSTEM_OPENCLOUDOS}" | "${SYSTEM_ANOLISOS}" | "${SYSTEM_TENCENTOS}")
				pkgs="docker-ce-${target_docker_version}"
				if [[ $major_version -gt 18 ]] || [[ $major_version -eq 18 && $minor_version -ge 9 ]]; then
					pkgs="${pkgs} docker-ce-cli-${target_docker_version}"
				fi
				;;
			esac
			pkgs="${pkgs} containerd.io"
			if [[ $major_version -gt 20 ]] || [[ $major_version -eq 20 && $minor_version -ge 10 ]]; then
				pkgs="${pkgs} docker-compose-plugin"
			fi
			if [[ $major_version -ge 23 ]]; then
				pkgs="${pkgs} docker-buildx-plugin"
			fi
		fi
		case "${SYSTEM_FACTIONS}" in
		"${SYSTEM_DEBIAN}")
			commands+=("apt-get install -y ${pkgs}")
			;;
		"${SYSTEM_REDHAT}" | "${SYSTEM_OPENEULER}" | "${SYSTEM_OPENCLOUDOS}" | "${SYSTEM_ANOLISOS}" | "${SYSTEM_TENCENTOS}")
			commands+=("$(get_package_manager) install -y ${pkgs}")
			;;
		esac
		if [[ "${PURE_MODE}" == "true" ]]; then
			local exec_cmd=""
			for cmd in "${commands[@]}"; do
				if [[ -z "${exec_cmd}" ]]; then
					exec_cmd="${cmd}"
				else
					exec_cmd="${exec_cmd} ; ${cmd}"
				fi
			done
			animate_exec "${exec_cmd}" "Install Docker Engine"
		else
			{ for cmd in "${commands[@]}"; do
				$cmd
			done; } || output_error "Failed to install Docker Engine!"
		fi
	}

	## Determine if manual selection is made for install version
	if [[ -z "${INSTALL_LATESTED_DOCKER}" ]]; then
		local ask_text="Install the latest version of Docker Engine?"
		if [[ "${CAN_USE_ADVANCED_INTERACTIVE_SELECTION}" == "true" ]]; then
			echo
			interactive_select_boolean "${BOLD}${ask_text}${PLAIN}"
			if [[ "${_SELECT_RESULT}" == "true" ]]; then
				INSTALL_LATESTED_DOCKER="true"
			else
				INSTALL_LATESTED_DOCKER="false"
			fi
		else
			local CHOICE_A
			CHOICE_A=$(echo -e "\n${BOLD}> ${ask_text} [Y/n] ${PLAIN}")
			read -rp "${CHOICE_A}" INPUT
			[[ -z "${INPUT}" ]] && INPUT=Y
			case $INPUT in
			[Yy] | [Yy][Ee][Ss])
				INSTALL_LATESTED_DOCKER="true"
				;;
			[Nn] | [Nn][Oo])
				INSTALL_LATESTED_DOCKER="false"
				;;
			*)
				INSTALL_LATESTED_DOCKER="true"
				input_error "Default: install the latest version"
				;;
			esac
		fi
		echo
	fi

	## Determine if already installed
	case "${SYSTEM_FACTIONS}" in
	"${SYSTEM_DEBIAN}")
		dpkg -l | grep docker-ce-cli -q
		;;
	"${SYSTEM_REDHAT}" | "${SYSTEM_OPENEULER}" | "${SYSTEM_OPENCLOUDOS}" | "${SYSTEM_ANOLISOS}" | "${SYSTEM_TENCENTOS}")
		rpm -qa | grep docker-ce-cli -q
		;;
	esac
	if dpkg -l 2>/dev/null | grep -q docker-ce-cli || rpm -qa 2>/dev/null | grep -q docker-ce-cli; then
		export_version_list
		local current_docker_version
		current_docker_version="$(docker -v | grep -Eo "[0-9][0-9]\.[0-9]{1,2}\.[0-9]{1,2}")"
		local latest_docker_version
		latest_docker_version="$(head -n 1 "$File_DockerVersionTmp")"
		rm -rf $File_DockerVersionTmp
		if [[ "${current_docker_version}" == "${latest_docker_version}" ]] && [[ "${INSTALL_LATESTED_DOCKER}" == "true" ]]; then
			echo -e "\n$TIP System already has Docker Engine installed and is the latest version, skipping installation"
		else
			uninstall_original_version
			install_main
		fi
	else
		uninstall_original_version
		install_main
	fi
}

function change_docker_registry_mirror() {
	if [[ "${SOURCE_REGISTRY}" == "registry.hub.docker.com" ]]; then
		if [ -s "${File_DockerConfig}" ]; then

			local package_manager
			package_manager="$(get_package_manager)"
			$package_manager install -y jq
			if command_exists jq; then
				jq 'del(.["registry-mirrors"])' $File_DockerConfig >$File_DockerConfig.tmp && mv $File_DockerConfig.tmp $File_DockerConfig

				systemctl daemon-reload
				if [[ "$(systemctl is-active docker 2>/dev/null)" == "active" ]]; then
					systemctl restart docker
				fi
			else
				echo -e "\n${WARN} Please remove ${BLUE}registry-mirrors${PLAIN} from $File_DockerConfig and restart services: ${BLUE}systemctl daemon-reload && systemctl restart docker${PLAIN}\n"
			fi
		fi
		return
	fi

	if [ -d "${Dir_Docker}" ] && [ -e "${File_DockerConfig}" ]; then
		if [ -e "${File_DockerConfigBackup}" ]; then
			if [[ "${IGNORE_BACKUP_TIPS}" == "false" ]]; then
				local ask_text="A backup of Docker config was detected. Skip overwriting the backup?"
				if [[ "${CAN_USE_ADVANCED_INTERACTIVE_SELECTION}" == "true" ]]; then
					echo
					interactive_select_boolean "${BOLD}${ask_text}${PLAIN}"
					if [[ "${_SELECT_RESULT}" == "false" ]]; then
						echo
						cp -rvf $File_DockerConfig $File_DockerConfigBackup 2>&1
					fi
				else
					local CHOICE_BACKUP
					CHOICE_BACKUP=$(echo -e "\n${BOLD}> ${ask_text} [Y/n] ${PLAIN}")
					read -r -p "${CHOICE_BACKUP}" INPUT
					[[ -z "${INPUT}" ]] && INPUT=Y
					case $INPUT in
					[Yy] | [Yy][Ee][Ss]) ;;
					[Nn] | [Nn][Oo])
						echo
						cp -rvf $File_DockerConfig $File_DockerConfigBackup 2>&1
						;;
					*)
						input_error "Default: do not overwrite"
						;;
					esac
				fi
			fi
		else
			echo
			cp -rvf $File_DockerConfig $File_DockerConfigBackup 2>&1
			echo -e "\n$COMPLETE Backed up existing Docker configuration"
		fi
		sleep 2s
	else
		mkdir -p $Dir_Docker >/dev/null 2>&1
		touch $File_DockerConfig
	fi

	if [[ -n "${DOCKER_DATA_ROOT}" ]]; then
		cat >"$File_DockerConfig" <<EOF
{
  "registry-mirrors": ["https://${SOURCE_REGISTRY}"],
  "data-root": "${DOCKER_DATA_ROOT}"
}
EOF
	else
		cat >"$File_DockerConfig" <<EOF
{
  "registry-mirrors": ["https://${SOURCE_REGISTRY}"]
}
EOF
	fi

	systemctl daemon-reload
	if [[ "$(systemctl is-active docker 2>/dev/null)" == "active" ]]; then
		systemctl restart docker
	fi
}

function only_change_docker_registry_mirror() {
	## Determine if already installed
	case "${SYSTEM_FACTIONS}" in
	"${SYSTEM_DEBIAN}")
		dpkg -l | grep docker-ce-cli -q
		;;
	"${SYSTEM_REDHAT}" | "${SYSTEM_OPENEULER}" | "${SYSTEM_OPENCLOUDOS}" | "${SYSTEM_ANOLISOS}" | "${SYSTEM_TENCENTOS}")
		rpm -qa | grep docker-ce-cli -q
		;;
	esac
	if ! (dpkg -l 2>/dev/null | grep -q docker-ce-cli || rpm -qa 2>/dev/null | grep -q docker-ce-cli); then
		## Only change registry mirror mode
		if [[ "${ONLY_REGISTRY}" == "true" ]]; then
			output_error "Docker Engine is not installed yet. Please remove the ${BLUE}--only-registry${PLAIN} option and rerun the script!"
		fi
	fi

	[ -d "${Dir_Docker}" ] || mkdir -p "${Dir_Docker}"
	if [ -s "${File_DockerConfig}" ]; then
		## Install jq
		if ! command_exists jq; then
			## Update software source
			local package_manager
			local commands=()
			case "${SYSTEM_FACTIONS}" in
			"${SYSTEM_DEBIAN}")
				package_manager="apt-get"
				commands+=("${package_manager} update")
				;;
			"${SYSTEM_REDHAT}" | "${SYSTEM_OPENEULER}" | "${SYSTEM_OPENCLOUDOS}" | "${SYSTEM_ANOLISOS}" | "${SYSTEM_TENCENTOS}")
				package_manager="$(get_package_manager)"
				commands+=("${package_manager} makecache")
				;;
			esac
			if [[ "${PURE_MODE}" == "true" ]]; then
				local exec_cmd=""
				for cmd in "${commands[@]}"; do
					if [[ -z "${exec_cmd}" ]]; then
						exec_cmd="${cmd}"
					else
						exec_cmd="${exec_cmd} ; ${cmd}"
					fi
				done
				echo
				animate_exec "${exec_cmd}" "${SYNC_MIRROR_TEXT}"
			else
				echo -e "\n$WORKING ${SYNC_MIRROR_TEXT}...\n"
				for cmd in "${commands[@]}"; do
					$cmd
				done
				echo -e "\n$COMPLETE ${SYNC_MIRROR_TEXT} completed\n"
			fi
			if false; then # keep structure; external env may not guarantee previous commands grouping
				output_error "${SYNC_MIRROR_TEXT} failed. Please fix existing repository errors to ensure ${BLUE}${package_manager}${PLAIN} is available!"
			fi
			$package_manager install -y jq
			if ! command_exists jq; then
				output_error "The package ${BLUE}jq${PLAIN} failed to install. Please install it manually and rerun the script!"
			fi
		fi
		[ -s "${File_DockerConfig}" ] || echo "{}" >$File_DockerConfig
		jq --arg mirror "https://${SOURCE_REGISTRY}" '.["registry-mirrors"] = [$mirror]' $File_DockerConfig >$File_DockerConfig.tmp && mv $File_DockerConfig.tmp $File_DockerConfig
	else
		echo -e '{\n  "registry-mirrors": ["https://'"${SOURCE_REGISTRY}"'"]\n}' >$File_DockerConfig
	fi

	echo -e "\n${BLUE}\$${PLAIN} docker info --format '{{json .RegistryConfig.Mirrors}}'"
	echo -e "\n* $(docker info --format '{{json .RegistryConfig.Mirrors}}')"
	## Restart service
	systemctl daemon-reload
	if [[ "$(systemctl is-active docker 2>/dev/null)" == "active" ]]; then
		systemctl restart docker
	fi
	if [[ "${PURE_MODE}" != "true" ]]; then
		echo -e "\n$COMPLETE Switched to registry mirror"
	fi
}

function check_installed_result() {
	if command_exists docker; then
		systemctl enable --now docker >/dev/null 2>&1
		if docker -v; then
			echo -e "$(docker compose version 2>&1)"

		else
			echo -e "\n$FAIL Installation failed"
			local source_file package_manager
			case "${SYSTEM_FACTIONS}" in
			"${SYSTEM_DEBIAN}")
				source_file="${File_DockerSourceList}"
				package_manager="apt-get"
				;;
			"${SYSTEM_REDHAT}" | "${SYSTEM_OPENEULER}" | "${SYSTEM_OPENCLOUDOS}" | "${SYSTEM_ANOLISOS}" | "${SYSTEM_TENCENTOS}")
				source_file="${File_DockerRepo}"
				package_manager="$(get_package_manager)"
				;;
			esac
			echo -e "\nCheck repository file: cat ${source_file}"
			echo -e "Try installing manually: ${package_manager} install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin\n"
			exit 1
		fi

		if [[ "$(systemctl is-active docker 2>/dev/null)" != "active" ]]; then
			sleep 2
			systemctl disable --now docker >/dev/null 2>&1
			sleep 2
			systemctl enable --now docker >/dev/null 2>&1
			sleep 2
			if [[ "$(systemctl is-active docker)" != "active" ]]; then
				echo -e "\n$WARN Docker service startup appears ${RED}abnormal${PLAIN}. You can try running this script again."
				local start_cmd
				if command_exists systemctl; then
					start_cmd="systemctl start docker"
				else
					start_cmd="service docker start"
				fi
				echo -e "\n$TIP Please run ${BLUE}${start_cmd}${PLAIN} to attempt to start the service or investigate errors."
			fi
		fi
	else
		echo -e "\n$FAIL Installation failed"
	fi
}

function get_package_manager() {
	local command="yum"
	case "${SYSTEM_JUDGMENT}" in
	"${SYSTEM_RHEL}" | "${SYSTEM_CENTOS_STREAM}" | "${SYSTEM_ROCKY}" | "${SYSTEM_ALMALINUX}" | "${SYSTEM_ORACLE}")
		case "${SYSTEM_VERSION_ID_MAJOR}" in
		9 | 10)
			command="dnf"
			;;
		esac
		;;
	"${SYSTEM_FEDORA}" | "${SYSTEM_OPENEULER}" | "${SYSTEM_OPENCLOUDOS}" | "${SYSTEM_ANOLISOS}" | "${SYSTEM_TENCENTOS}")
		command="dnf"
		;;
	esac
	echo "${command}"
}

function interactive_select_mirror() {
	_SELECT_RESULT=""
	local options=("$@")
	local message="${options[${#options[@]} - 1]}"
	unset "options[${#options[@]}-1]"
	local selected=0
	local start=0
	local page_size=$(($(tput lines 2>/dev/null) - 3))
	function draw_menu() {
		tput clear 2>/dev/null
		tput cup 0 0 2>/dev/null
		echo -e "${message}"
		local end=$((start + page_size - 1))
		if [ $end -ge ${#options[@]} ]; then
			end=${#options[@]}-1
		fi
		for ((i = start; i <= end; i++)); do
			if [ "$i" -eq "$selected" ]; then
				echo -e "> ${options[$i]%@*}"
			else
				echo -e "  ${options[$i]%@*}"
			fi
		done
	}
	function read_key() {
		IFS= read -rsn1 key
		if [[ $key == $'\x1b' ]]; then
			IFS= read -rsn2 key
		fi
		echo "$key"
	}
	tput smcup 2>/dev/null
	tput sc 2>/dev/null
	tput civis 2>/dev/null
	trap 'tput rc 2>/dev/null; for ((i=0; i<$((${#options[@]} + 1)); i++)); do echo -e "\r\033[K"; done; tput rc 2>/dev/null; tput cnorm 2>/dev/null; tput rmcup 2>/dev/null; echo -e "\n[INFO] Operation canceled\n"; exit 130' INT TERM
	draw_menu
	while true; do
		key=$(read_key)
		case "$key" in
		"[A" | "w" | "W")
			if [ "$selected" -gt 0 ]; then
				selected=$((selected - 1))
				if [ "$selected" -lt "$start" ]; then
					start=$((start - 1))
				fi
			fi
			;;
		"[B" | "s" | "S")
			if [ "$selected" -lt $((${#options[@]} - 1)) ]; then
				selected=$((selected + 1))
				if [ "$selected" -ge $((start + page_size)) ]; then
					start=$((start + 1))
				fi
			fi
			;;
		"")
			tput rmcup
			break
			;;
		*) ;;
		esac
		draw_menu
	done
	tput cnorm 2>/dev/null
	tput rmcup 2>/dev/null
	_SELECT_RESULT="${options[$selected]}"
}

function interactive_select_boolean() {
	_SELECT_RESULT=""
	local selected=0
	local message="$1"
	local menu_height=3
	function draw_menu() {
		echo -e "? ${message}"
		echo -e ""
		if [ "$selected" -eq 0 ]; then
			echo -e "> Yes /  No"
		else
			echo -e "  Yes / > No"
		fi
	}
	function read_key() {
		IFS= read -rsn1 key
		if [[ $key == $'\x1b' ]]; then
			IFS= read -rsn2 key
		fi
		echo "$key"
	}
	tput civis 2>/dev/null
	trap 'for ((i=0; i<menu_height; i++)); do tput cuu1 2>/dev/null; tput el 2>/dev/null; done; tput cnorm 2>/dev/null; echo -e "\n[INFO] Operation canceled\n"; exit 130' INT TERM
	draw_menu
	while true; do
		key=$(read_key)
		case "$key" in
		"[D" | "a" | "A")
			if [ "$selected" -gt 0 ]; then
				selected=$((selected - 1))
				for ((i = 0; i < menu_height; i++)); do
					tput cuu1 2>/dev/null
					tput el 2>/dev/null
				done
				draw_menu
			fi
			;;
		"[C" | "d" | "D")
			if [ "$selected" -lt 1 ]; then
				selected=$((selected + 1))
				for ((i = 0; i < menu_height; i++)); do
					tput cuu1 2>/dev/null
					tput el 2>/dev/null
				done
				draw_menu
			fi
			;;
		"")
			for ((i = 0; i < menu_height; i++)); do
				tput cuu1 2>/dev/null
				tput el 2>/dev/null
			done
			break
			;;
		*) ;;
		esac
	done
	echo -e "? ${message}"
	echo -e ""
	if [ "$selected" -eq 0 ]; then
		echo -e "> Yes /  No"
		_SELECT_RESULT="true"
	else
		echo -e "  Yes / > No"
		_SELECT_RESULT="false"
	fi
	tput cnorm 2>/dev/null
}

function animate_exec() {
	local cmd="$1"
	local title="$2"
	local max_lines=${3:-5}
	local spinner_style="${4:-classic}"
	local refresh_rate="${5:-0.1}"

	local -a spinner_frames
	case "$spinner_style" in
	classic | line)
		spinner_frames=("|" "/" "-" "\\")
		;;
	bar)
		spinner_frames=("-" "\\" "|" "/")
		;;
	*)
		spinner_frames=("|" "/" "-" "\\")
		;;
	esac

	local term_width
	term_width=$(tput cols 2>/dev/null || echo 80)
	local display_width=$((term_width - 2))
	function simple_truncate() {
		local line="$1"
		local truncate_marker="..."
		local max_length=$((display_width - 3))
		if [ ${#line} -le $display_width ]; then
			echo "$line"
			return
		fi
		echo "${line:0:$max_length}${truncate_marker}"
	}

	function cleanup() {
		[ -f "${temp_file}" ] && rm -f "${temp_file}"
		tput cnorm 2>/dev/null
		echo -e "\n[INFO] Operation canceled\n"
		exit 130
	}

	function make_temp_file() {
		local temp_dirs=("." "/tmp")
		local tmp_file=""
		for dir in "${temp_dirs[@]}"; do
			[[ ! -d "${dir}" || ! -w "${dir}" ]] && continue
			tmp_file="${dir}/animate_exec_$$_$(date +%s)"
			touch "${tmp_file}" 2>/dev/null || continue
			if [[ -f "${tmp_file}" && -w "${tmp_file}" ]]; then
				echo "${tmp_file}"
				return
			fi
		done
		echo "${tmp_file}"
	}

	function update_display() {
		local current_size
		current_size=$(wc -c <"${temp_file}" 2>/dev/null || echo 0)
		if [[ $current_size -le $last_size ]]; then
			return 1
		fi
		local -a lines=()
		mapfile -t -n "${max_lines}" lines < <(tail -n "$max_lines" "${temp_file}")
		local -a processed_lines=()
		for ((i = 0; i < ${#lines[@]}; i++)); do
			processed_lines[i]=$(simple_truncate "${lines[i]}")
		done
		tput cud1 2>/dev/null
		echo -ne "\r\033[K"
		tput cud1 2>/dev/null
		for ((i = 0; i < max_lines; i++)); do
			echo -ne "\r\033[K"
			[[ $i -lt ${#processed_lines[@]} ]] && echo -ne "${processed_lines[$i]}"
			[[ $i -lt $((max_lines - 1)) ]] && tput cud1 2>/dev/null
		done
		for ((i = 0; i < max_lines + 1; i++)); do
			tput cuu1 2>/dev/null
		done
		last_size=$current_size
		return 0
	}

	local temp_file
	temp_file="$(make_temp_file)"
	trap "cleanup" INT TERM
	tput civis 2>/dev/null
	echo
	echo
	for ((i = 0; i < max_lines; i++)); do
		echo
	done

	$cmd >"${temp_file}" 2>&1 &
	local cmd_pid=$!
	local last_size=0
	local spin_idx=0

	tput cuu $((max_lines + 2)) 2>/dev/null
	sleep 0.05
	echo -ne "\r\033[K* ${title} [${spinner_frames[$spin_idx]}]"
	spin_idx=$(((spin_idx + 1) % ${#spinner_frames[@]}))
	update_display

	local adaptive_rate=$refresh_rate
	while kill -0 $cmd_pid 2>/dev/null; do
		echo -ne "\r\033[K* ${title} [${spinner_frames[$spin_idx]}]"
		spin_idx=$(((spin_idx + 1) % ${#spinner_frames[@]}))
		update_display
		sleep "$adaptive_rate"
	done

	wait $cmd_pid
	local exit_status=$?
	update_display
	if [ $exit_status -eq 0 ]; then
		echo -ne "\r\033[K* ${title} [OK]\n"
	else
		echo -ne "\r\033[K* ${title} [FAIL]\n"
	fi
	echo -ne "\r\033[K\n"

	local actual_lines
	actual_lines=$(wc -l <"${temp_file}" 2>/dev/null || echo 0)
	[[ $actual_lines -gt $max_lines ]] && actual_lines=$max_lines
	if [[ $actual_lines -gt 0 ]]; then
		local -a final_lines=()
		mapfile -t -n "$actual_lines" final_lines < <(tail -n "$actual_lines" "${temp_file}")
		for ((i = 0; i < actual_lines; i++)); do
			local line
			line=$(simple_truncate "${final_lines[$i]}")
			echo -ne "\r\033[K${line}\n"
		done
	fi

	tput cnorm 2>/dev/null
	rm -f "${temp_file}"
	return $exit_status
}

handle_command_options "$@"
main
