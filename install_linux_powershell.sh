#!/bin/bash

# PowerShell 在 Linux 上的安装脚本

echo "==================================="
echo "  PowerShell Linux 安装脚本"
echo "==================================="
echo ""

# 检测 Linux 发行版
if [ -f /etc/os-release ]; then
	# shellcheck source=/dev/null
	. /etc/os-release
	OS=$ID
	VER=$VERSION_ID
else
	echo "无法检测 Linux 发行版"
	exit 1
fi

echo "检测到系统: $OS $VER"
echo ""

# 检查是否已安装
if command -v pwsh &>/dev/null; then
	echo "PowerShell 已安装！"
	pwsh --version
	echo ""
	read -p "是否要重新安装? (y/N): " -n 1 -r
	echo
	if [[ ! $REPLY =~ ^[Yy]$ ]]; then
		exit 0
	fi
fi

# 根据不同发行版安装
case $OS in
ubuntu | debian)
	echo "正在为 Ubuntu/Debian 安装 PowerShell..."

	# 更新包列表
	sudo apt-get update

	# 安装依赖
	sudo apt-get install -y wget apt-transport-https software-properties-common

	# 下载 Microsoft 仓库 GPG 密钥
	wget -q "https://packages.microsoft.com/config/$OS/$VER/packages-microsoft-prod.deb"

	# 注册 Microsoft 仓库 GPG 密钥
	sudo dpkg -i packages-microsoft-prod.deb

	# 删除下载的包
	rm packages-microsoft-prod.deb

	# 更新包列表
	sudo apt-get update

	# 安装 PowerShell
	sudo apt-get install -y powershell
	;;

fedora)
	echo "正在为 Fedora 安装 PowerShell..."

	# 注册 Microsoft 仓库
	sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
	curl https://packages.microsoft.com/config/rhel/8/prod.repo | sudo tee /etc/yum.repos.d/microsoft.repo

	# 安装 PowerShell
	sudo dnf install -y powershell
	;;

centos | rhel)
	echo "正在为 CentOS/RHEL 安装 PowerShell..."

	# 注册 Microsoft 仓库
	curl https://packages.microsoft.com/config/rhel/"$VER"/prod.repo | sudo tee /etc/yum.repos.d/microsoft.repo

	# 安装 PowerShell
	sudo yum install -y powershell
	;;

arch | manjaro)
	echo "正在为 Arch Linux 安装 PowerShell..."

	# 使用 AUR
	if command -v yay &>/dev/null; then
		yay -S powershell-bin
	elif command -v paru &>/dev/null; then
		paru -S powershell-bin
	else
		echo "请先安装 yay 或 paru AUR 助手"
		exit 1
	fi
	;;

opensuse*)
	echo "正在为 openSUSE 安装 PowerShell..."

	# 注册 Microsoft 仓库
	sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
	sudo zypper addrepo https://packages.microsoft.com/config/opensuse/"$VER"/prod.repo

	# 安装 PowerShell
	sudo zypper install -y powershell
	;;

*)
	echo "不支持的 Linux 发行版: $OS"
	echo ""
	echo "请访问以下链接手动安装:"
	echo "https://docs.microsoft.com/zh-cn/powershell/scripting/install/installing-powershell-on-linux"
	exit 1
	;;
esac

echo ""
echo "==================================="
echo "  安装完成！"
echo "==================================="
echo ""

# 验证安装
if command -v pwsh &>/dev/null; then
	echo "✓ PowerShell 安装成功！"
	echo ""
	pwsh --version
	echo ""
	echo "使用方法:"
	echo "  - 运行 PowerShell: pwsh"
	echo "  - 运行脚本: pwsh script.ps1"
	echo "  - 退出 PowerShell: exit"
	echo ""

	read -p "是否现在启动 PowerShell? (Y/n): " -n 1 -r
	echo
	if [[ ! $REPLY =~ ^[Nn]$ ]]; then
		pwsh
	fi
else
	echo "✗ PowerShell 安装失败，请检查错误信息"
	exit 1
fi
