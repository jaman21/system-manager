#!/bin/sh
set -e

set_runlevel() {
	level="$1"

	case "$level" in
	"1")
		sudo systemctl set-default rescue.target
		echo "Set to single user console for next boot"
		;;
	"3")
		sudo systemctl set-default multi-user.target
		echo "Set to multi-user console for next boot"
		;;
	"5")
		sudo systemctl set-default graphical.target
		echo "Set to graphical desktop for next boot"
		;;
	*)
		echo "Invalid runlevel. Use 1, 3, or 5"
		exit 1
		;;
	esac

	printf "Reboot now? (y/N): "
	read -r choice
	if [ "$choice" = "y" ] || [ "$choice" = "Y" ]; then
		echo "Rebooting..."
		sudo reboot
	else
		exit
	fi
}

show_status() {
	current=$(systemctl get-default 2>/dev/null || echo "unknown")
	echo "Current: $current"
}

main() {
	if [ -n "$1" ]; then
		case "$1" in
		"1" | "3" | "5")
			set_runlevel "$1"
			;;
		"-s" | "--status")
			show_status
			;;
		*)
			echo "Usage: $0 [1|3|5] or $0 -s"
			echo "  1 = Single user console"
			echo "  3 = Multi-user console"
			echo "  5 = Graphical desktop"
			echo "  -s = Show status"
			;;
		esac
	else
		while true; do
			clear
			echo "=== Runlevel Configuration ==="
			show_status
			echo "1) Single user console (1)"
			echo "2) Multi-user console (3)"
			echo "3) Graphical desktop (5)"
			echo "q) Exit"
			printf "Choice (1,2,3,q): "
			read -r choice
			case $choice in
			1) set_runlevel 1 ;;
			2) set_runlevel 3 ;;
			3) set_runlevel 5 ;;
			q) exit ;;
			*)
				echo "Invalid choice"
				sleep 1
				;;
			esac
		done
	fi
}

main "$@"
