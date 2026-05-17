#!/bin/bash
set -euo pipefail
abort_unless_macos() {
	local os
	os="$(uname -s 2>/dev/null || true)"
	if [[ "${os:-}" != "Darwin" ]]; then
		echo "cleanup-macos.sh: need Darwin, got '${os:-unknown}'" >&2
		exit 1
	fi
	if [[ ! -x /usr/bin/defaults ]]; then
		echo "cleanup-macos.sh: /usr/bin/defaults missing" >&2
		exit 1
	fi
}

abort_unless_macos

build_clean_roots() {
	CLEAN_ROOTS=("$HOME")
	shopt -s nullglob
	local vol
	for vol in /Volumes/*/; do
		vol="${vol%/}"
		[[ -d "$vol" ]] || continue
		[[ "$(cd "$vol" && pwd -P)" == "$(cd "$HOME" && pwd -P)" ]] && continue
		CLEAN_ROOTS+=("$vol")
	done
	shopt -u nullglob
}

build_clean_roots

for root in "${CLEAN_ROOTS[@]}"; do
	[[ -d "$root" ]] || continue
	find "$root" -type f \( \
		-name ".DS_Store" \
		-o -name "._*" \
		-o -name "*.pyc" \
		-o -name "*.pyo" \
		-o -name "*.pyd" \
		-o -name "Thumbs.db" \
		-o -name ".LSOverride" \
		\) -delete 2>/dev/null || true
	find "$root" -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	find "$root" -type d -name ".AppleDouble" -exec rm -rf {} + 2>/dev/null || true
done

find "$HOME" -type d -empty -delete 2>/dev/null || true

defaults write com.apple.desktopservices DSDontWriteNetworkStores true
defaults write com.apple.desktopservices DSDontWriteUSBStores true

ensure_copyfile_disable_in_shell_rc() {
	local line="export COPYFILE_DISABLE=1"
	local f

	for f in "${HOME}/.zshrc" "${HOME}/.bash_profile"; do
		if [[ -f "$f" ]] && grep -qF "COPYFILE_DISABLE=1" "$f" 2>/dev/null; then
			continue
		fi
		{
			echo ""
			echo "$line"
		} >>"$f"
	done

	export COPYFILE_DISABLE=1
}

ensure_copyfile_disable_in_shell_rc

killall Finder 2>/dev/null || true
