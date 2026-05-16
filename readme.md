# Scripts

## Get them
from the web install Docker, no local file needed first:

```bash
bash <(curl -sSL https://raw.githubusercontent.com/jaman21/system-manager/main/dm.sh)
```

---

## What each file does

| File | Purpose |
| --- | --- |
| `cleanup-macos.sh` | macOS: remove junk like `.DS_Store` and Python caches; skip extra metadata on external disks |
| `di.sh` | Install and tune Docker CE and mirrors |
| `dm.sh` | Docker container tools (menu, layer mount, etc.) |
| `goinst.sh` | Install a fixed Go version |
| `install_cnlinux.sh` | Linux Chinese locale and input (fcitx5, etc.) |
| `install_conda_linux.sh` | Miniconda on Linux (and similar) |
| `install_conda_msys2.sh` | Miniconda on MSYS2 only |
| `install_linux_powershell.sh` | PowerShell (`pwsh`) on common Linux distros |
| `install_package.sh` | Flatpak setup, mirror, and a set of apps |
| `nodejs-update.sh` | Drop distro Node/npm; install Node from upstream (LTS, current, or version) |
| `shf.sh` | Install `shfmt` and format shell files or a folder |
| `switch_desktop.sh` | Pick default X session via `update-alternatives` |
| `switch_runlevel.sh` | Set systemd default target (rescue / multi-user / GUI); optional reboot |
| `uninstall_conda.sh` | Remove Conda, shell hooks, and common install/cache dirs |
