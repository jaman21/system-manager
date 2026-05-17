#!/bin/sh
set -eu

OS_NAME=$(uname -s 2>/dev/null || echo unknown)
if command -v conda >/dev/null 2>&1; then
	if [ -n "${CONDA_PREFIX:-}" ]; then
		while [ -n "${CONDA_PREFIX:-}" ]; do
			conda deactivate >/dev/null 2>&1 || break
		done
	fi
	conda init --reverse zsh >/dev/null 2>&1 || echo "Failed to reverse conda init for zsh"
	conda init --reverse bash >/dev/null 2>&1 || echo "Failed to reverse conda init for bash"
fi

for f in ~/.zshrc ~/.bashrc ~/.bash_profile ~/.profile; do
	[ -f "$f" ] || continue
	if [ "$OS_NAME" = "Darwin" ]; then
		sed -i '' '/^# >>> conda initialize >>>$/,/^# <<< conda initialize <<</d' "$f" || echo "Failed to remove conda initialize block from $f"
		sed -i '' '/^# >>> conda extra library paths >>>$/,/^# <<< conda extra library paths <<</d' "$f" || echo "Failed to remove conda extra library paths block from $f"
	else
		sed -i '/^# >>> conda initialize >>>$/,/^# <<< conda initialize <<</d' "$f" || echo "Failed to remove conda initialize block from $f"
		sed -i '/^# >>> conda extra library paths >>>$/,/^# <<< conda extra library paths <<</d' "$f" || echo "Failed to remove conda extra library paths block from $f"
	fi
done

for p in /opt/miniconda3 ~/miniconda3 ~/anaconda3; do
	if [ -d "$p" ]; then
		rm -rf "$p" || echo "Failed to delete $p"
	fi
done

rm -rf ~/.conda || echo "Failed to delete ~/.conda"
rm -rf ~/.condarc || echo "Failed to delete ~/.condarc"
rm -rf ~/.continuum || echo "Failed to delete ~/.continuum"
if [ "$OS_NAME" = "Darwin" ]; then
	rm -rf ~/Library/Caches/conda || echo "Failed to delete ~/Library/Caches/conda"
else
	rm -rf ~/.cache/conda || echo "Failed to delete ~/.cache/conda"
fi
