#!/usr/bin/env bash
set -euo pipefail

die() {
  echo "$*" >&2
  exit 1
}

have() {
  command -v "$1" >/dev/null 2>&1
}

# MSYS2: MINGW64/UCRT64/CLANG64/MINGW32; 纯 MSYS shell 为 MSYS_NT-*
uname_s_is_msys2_windows() {
  case "$(uname -s)" in
  MINGW* | MSYS_NT* | UCRT64_NT* | CLANG64_NT*) return 0 ;;
  *) return 1 ;;
  esac
}

remove_distro_node_packages() {
  # MSYS2 上通常不用 sudo 跑 pacman; 且未必安装 sudo
  if uname_s_is_msys2_windows && have pacman; then
    pacman -Rns --noconfirm nodejs || true
    pacman -Rns --noconfirm npm || true
    return 0
  fi
  have sudo || die "sudo required to remove distro node"
  if have apt-get; then
    sudo apt-get remove -y nodejs
    sudo apt-get remove -y npm || true
    return 0
  fi
  if have apt; then
    sudo apt remove -y nodejs
    sudo apt remove -y npm || true
    return 0
  fi
  if have dnf; then
    sudo dnf remove -y nodejs
    return 0
  fi
  if have yum; then
    sudo yum remove -y nodejs
    return 0
  fi
  if have pacman; then
    sudo pacman -Rns --noconfirm nodejs
    sudo pacman -Rns --noconfirm npm || true
    return 0
  fi
  if have apk; then
    sudo apk del nodejs
    sudo apk del npm || true
    return 0
  fi
  if have zypper; then
    sudo zypper remove -y nodejs
    return 0
  fi
  die "no supported package manager (apt-get/apt/dnf/yum/pacman/apk/zypper) to remove distro node"
}

home_root="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
if [[ "$(id -u)" -eq 0 ]]; then
  NODE_PREFIX="${NODE_PREFIX:-/opt/node}"
else
  NODE_PREFIX="${NODE_PREFIX:-${home_root}/node}"
fi

usage() {
  cat <<EOF
Usage: $0 [VERSION]
VERSION: lts|current|MAJOR|x.y.z  (default: lts)
Install dir: NODE_PREFIX (default: /opt/node if root, else <this-repo>/tools/node)
EOF
}

case "${1:-}" in
-h | --help)
  usage
  exit 0
  ;;
esac

if [[ $# -eq 0 ]]; then
  NODE_SPEC=lts
elif [[ $# -eq 1 ]]; then
  case "$1" in
  -*)
    die "unknown option: $1"
    ;;
  *)
    NODE_SPEC="$1"
    ;;
  esac
else
  die "usage: $0 [VERSION]"
fi

init_brew_path() {
  command -v brew >/dev/null 2>&1 && return 0
  local d
  for d in /opt/homebrew/bin /usr/local/bin "$HOME/.linuxbrew/bin" "$HOME/.linuxbrew/Homebrew/bin"; do
    [[ -x "$d/brew" ]] || continue
    PATH="$d:$PATH"
    export PATH
    return 0
  done
  return 1
}

resolve_node_dist_version() {
  local channel="$1"
  local request="${2:-}"
  python3 - "$channel" "$request" <<'PY'
import json, re, sys, urllib.request

channel, request = sys.argv[1], sys.argv[2].strip()

def load():
    url = "https://nodejs.org/dist/index.json"
    req = urllib.request.Request(url, headers={"User-Agent": "nodejs-update.sh"})
    with urllib.request.urlopen(req, timeout=120) as r:
        return json.load(r)

data = load()
listed = {r["version"] for r in data}

if not request:
    if channel == "lts":
        for rel in data:
            if rel.get("lts"):
                print(rel["version"])
                sys.exit(0)
        sys.exit("no LTS release")
    if channel != "current":
        sys.exit("invalid NODE_CHANNEL")
    print(data[0]["version"])
    sys.exit(0)

if re.fullmatch(r"v?\d+", request):
    m = int(request.lstrip("v"))
    prefix = f"v{m}."
    cand = [r["version"] for r in data if r["version"].startswith(prefix)]
    if not cand:
        sys.exit(f"no releases for major v{m}.x")
    print(max(cand, key=lambda v: tuple(map(int, v.lstrip("v").split(".")))))
    sys.exit(0)

mo = re.fullmatch(r"(v?)(\d+)\.(\d+)\.(\d+)", request)
if not mo:
    sys.exit("invalid version format")

ver = "v" + ".".join(mo.group(2, 3, 4))
if ver not in listed:
    sys.exit(f"version not listed: {ver}")
print(ver)
PY
}

resolve_from_spec() {
  case "$NODE_SPEC" in
  lts | LTS) resolve_node_dist_version lts "" ;;
  current | CURRENT) resolve_node_dist_version current "" ;;
  *) resolve_node_dist_version lts "$NODE_SPEC" ;;
  esac
}

node_os_arch() {
  local os arch
  case "$(uname -s)" in
  Darwin) os=darwin ;;
  Linux) os=linux ;;
  MINGW* | MSYS_NT* | UCRT64_NT* | CLANG64_NT*) os=win ;;
  *) die "unsupported OS: $(uname -s)" ;;
  esac
  case "$(uname -m)" in
  x86_64) arch=x64 ;;
  aarch64 | arm64) arch=arm64 ;;
  armv7l) arch=armv7l ;;
  *) die "unsupported CPU: $(uname -m)" ;;
  esac
  printf '%s %s' "$os" "$arch"
}

remove_mismatched_external_node() {
  local target_ver="$1"
  local rounds=0

  while ((rounds < 12)); do
    rounds=$((rounds + 1))
    local bin cur_ver before after orig_bin bp matched

    bin="$(command -v node 2>/dev/null || true)"
    [[ -z "$bin" ]] && return 0
    case "$bin" in
    "$NODE_PREFIX"/*) return 0 ;;
    esac
    cur_ver="$("$bin" -v 2>/dev/null | head -1 | tr -d '\r\n')"
    [[ -z "$cur_ver" ]] && return 0
    [[ "$cur_ver" == "$target_ver" ]] && return 0

    before="$bin"
    orig_bin="$bin"
    matched=0

    if [[ -n "${CONDA_PREFIX:-}" && "$orig_bin" == "${CONDA_PREFIX}/bin/node" ]] && command -v conda >/dev/null 2>&1; then
      matched=1
      conda remove -y nodejs || conda remove -y node || die "conda could not remove node (target $target_ver)"
    elif init_brew_path; then
      bp="$(brew --prefix || true)"
      if [[ -n "$bp" ]]; then
        case "$orig_bin" in
        "$bp/bin/node" | "$bp/opt/node/bin/node" | "$bp"/Cellar/node/*/bin/node)
          matched=1
          brew uninstall --force node || brew uninstall node || die "brew could not remove node (target $target_ver)"
          ;;
        esac
      fi
    fi

    if [[ "$matched" -eq 0 && -n "${NVM_DIR:-}" && "$orig_bin" == "${NVM_DIR}/"* ]]; then
      matched=1
      if [[ -s "${NVM_DIR}/nvm.sh" ]]; then
        # shellcheck disable=SC1090,SC1091
        . "${NVM_DIR}/nvm.sh"
      fi
      command -v nvm >/dev/null 2>&1 || die "nvm.sh missing for $orig_bin"
      nvm uninstall "$cur_ver" || die "nvm could not uninstall $cur_ver (target $target_ver)"
    fi

    if [[ "$matched" -eq 0 ]] && [[ "$(uname -s)" == Linux ]]; then
      case "$orig_bin" in
      /usr/bin/node | /usr/bin/nodejs | /bin/node)
        matched=1
        remove_distro_node_packages
        ;;
      esac
    fi

    if [[ "$matched" -eq 0 ]] && uname_s_is_msys2_windows; then
      case "$orig_bin" in
      /usr/bin/node | /usr/bin/nodejs | /bin/node | /mingw*/bin/node | /ucrt*/bin/node | /clang*/bin/node)
        matched=1
        remove_distro_node_packages
        ;;
      esac
    fi

    if [[ "$matched" -eq 0 ]]; then
      die "unsupported node at $orig_bin ($cur_ver); remove it first (target $target_ver)"
    fi

    hash -r || true

    after="$(command -v node 2>/dev/null || true)"
    [[ -z "$after" ]] && return 0
    case "$after" in
    "$NODE_PREFIX"/*) return 0 ;;
    esac
    cur_ver="$("$after" -v 2>/dev/null | head -1 | tr -d '\r\n')"
    [[ "$cur_ver" == "$target_ver" ]] && return 0
    [[ "$after" != "$before" ]] && continue
    die "node still $after ($cur_ver) after uninstall; target $target_ver"
  done

  die "too many uninstall rounds; target $target_ver"
}

install_via_conda() {
  local ver="${1:?}"
  [[ -n "${CONDA_PREFIX:-}" ]] || die "conda: CONDA_PREFIX empty"
  command -v conda >/dev/null 2>&1 || die "conda not on PATH"
  command -v python3 >/dev/null 2>&1 || die "python3 required"

  local major next ch="conda-forge"
  major="${ver#v}"
  major="${major%%.*}"
  [[ "$major" =~ ^[0-9]+$ ]] || die "bad version: $ver"
  next=$((major + 1))

  conda install -y --override-channels -c "$ch" "nodejs>=${major}.0.0,<${next}.0.0" || die "conda install nodejs failed (${ver})"
  hash -r 2>/dev/null || true
}

install_tarball() {
  local ver="$1"
  [[ -n "$ver" ]] || die "empty version"
  command -v curl >/dev/null 2>&1 || die "curl required"

  read -r os arch <<<"$(node_os_arch)"
  local tarball dir_name extract_top tmp
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  if [[ "$os" == win ]]; then
    command -v python3 >/dev/null 2>&1 || die "python3 required (Windows zip 解压)"
    tarball="node-${ver}-win-${arch}.zip"
    curl -fsSL "https://nodejs.org/dist/${ver}/${tarball}" -o "$tmp/$tarball"
    python3 -c 'import sys, zipfile; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])' "$tmp/$tarball" "$tmp"
  else
    tarball="node-${ver}-${os}-${arch}.tar.gz"
    curl -fsSL "https://nodejs.org/dist/${ver}/${tarball}" -o "$tmp/$tarball"
    tar -xzf "$tmp/$tarball" -C "$tmp"
  fi
  extract_top="$(find "$tmp" -maxdepth 1 -mindepth 1 -type d -name 'node-v*' | head -1)"
  [[ -n "$extract_top" ]] || die "extract failed"
  mkdir -p "$NODE_PREFIX"
  dir_name="$(basename "$extract_top")"
  rm -rf "${NODE_PREFIX:?}/$dir_name"
  mv "$extract_top" "$NODE_PREFIX/$dir_name"
  ln -sfn "$NODE_PREFIX/$dir_name" "$NODE_PREFIX/current"
  trap - EXIT
  rm -rf "$tmp"
}

install_official_binary() {
  command -v python3 >/dev/null 2>&1 || die "python3 required"
  local ver
  ver="$(resolve_from_spec)"
  remove_mismatched_external_node "$ver"
  install_tarball "$ver"
}

sync_conda_prefix() {
  command -v python3 >/dev/null 2>&1 || die "python3 required"
  command -v curl >/dev/null 2>&1 || die "curl required"
  local plan sync
  plan="$(resolve_from_spec)"
  install_via_conda "$plan"
  [[ -x "${CONDA_PREFIX}/bin/node" ]] || die "missing ${CONDA_PREFIX}/bin/node"
  sync="$("${CONDA_PREFIX}/bin/node" -v 2>/dev/null | head -1 | tr -d '\r\n')"
  [[ -n "$sync" ]] || die "no version from conda node"
  remove_mismatched_external_node "$sync"
  install_tarball "$sync"
}

write_root_profiled_node_path() {
  [[ "$(id -u)" -eq 0 ]] || return 0
  [[ -n "${NODEJS_UPDATE_NO_SYSTEM_PROFILE:-}" ]] && return 0
  [[ -d /etc/profile.d ]] || return 0
  [[ -x "${NODE_PREFIX}/current/bin/node" ]] || return 0
  local f="/etc/profile.d/openclaw-nodejs-local.sh"
  umask 022
  cat >"$f" <<EOF
# Node/npm under ${NODE_PREFIX}/current (nodejs-update.sh)
export PATH="${NODE_PREFIX}/current/bin:\$PATH"
EOF
  chmod 644 "$f" || true
}

export_current_node_path() {
  [[ -x "${NODE_PREFIX}/current/bin/node" ]] || return 0
  PATH="${NODE_PREFIX}/current/bin:${PATH:-}"
  export PATH
}

main() {
  if [[ -n "${CONDA_PREFIX:-}" ]] && command -v conda >/dev/null 2>&1; then
    sync_conda_prefix
  else
    install_official_binary
  fi
  export_current_node_path
  write_root_profiled_node_path
}

main "$@"
