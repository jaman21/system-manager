#!/usr/bin/env bash
set -euo pipefail

die() {
  echo "shf: $*" >&2
  exit 1
}

have() { command -v "$1" >/dev/null 2>&1; }

prepend_brew_to_path() {
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
}

ensure_brew_macos() {
  prepend_brew_to_path
  have brew && return 0
  have curl || die "curl required"
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" \
    || die "Homebrew failed"
  prepend_brew_to_path
  have brew || die "brew not on PATH"
}

install_shfmt_macos() {
  ensure_brew_macos
  brew list shfmt &>/dev/null || brew install -q shfmt || brew install shfmt
}

install_shfmt_linux() {
  if have apt-get; then
    sudo apt-get update -qq
    sudo apt-get install -y shfmt && return 0
  fi
  if have apt; then
    sudo apt update -qq
    sudo apt install -y shfmt && return 0
  fi
  if have dnf; then
    sudo dnf install -y shfmt 2>/dev/null && return 0
    sudo dnf install -y golang-github-mvdan-sh 2>/dev/null && return 0
  fi
  if have yum; then
    sudo yum install -y shfmt 2>/dev/null && return 0
  fi
  if have pacman; then
    sudo pacman -S --noconfirm shfmt && return 0
  fi
  if have apk; then
    sudo apk add --no-cache shfmt && return 0
  fi
  if have zypper; then
    sudo zypper install -y shfmt 2>/dev/null && return 0
  fi
  if have go; then
    go install mvdan.cc/sh/v3/cmd/shfmt@latest
    local gop
    gop="$(go env GOPATH 2>/dev/null)/bin"
    [[ -x "$gop/shfmt" ]] || die "go install failed"
    export PATH="$gop:$PATH"
    return 0
  fi
  die "no shfmt package found"
}

ensure_shfmt() {
  have shfmt && return 0
  case "$(uname -s)" in
  Darwin) install_shfmt_macos ;;
  Linux) install_shfmt_linux ;;
  *) die "unsupported OS: $(uname -s)" ;;
  esac
  have shfmt || die "shfmt missing"
}

collect_files() {
  local p="$1"
  shfpaths=()
  local line
  [[ -e "$p" ]] || die "not found: $p"
  if [[ -d "$p" ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
      [[ -n "$line" ]] && shfpaths+=("$line")
    done < <(shfmt -f "$p")
  elif [[ -f "$p" ]]; then
    shfpaths+=("$p")
  else
    die "not a file or directory: $p"
  fi
  [[ ${#shfpaths[@]} -gt 0 ]] || die "no shell files matched"
}

usage() {
  echo "usage: $(basename "$0") <file|dir>" >&2
}

main() {
  [[ $# -eq 1 ]] || {
    usage
    exit 1
  }

  ensure_shfmt

  local indent="${SHFMT_INDENT:-2}"
  [[ "$indent" =~ ^[0-9]+$ ]] || die "SHFMT_INDENT must be digits"

  collect_files "$1"

  shfmt -w -i "$indent" -bn -- "${shfpaths[@]}"
}

main "$@"
