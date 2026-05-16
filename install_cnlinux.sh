#!/bin/sh

set -e

PKG_MANAGER=""
DESKTOPS=""
ALL_USERS=""

detect_package_manager() {
  if [ -x "/usr/bin/pacman" ] && [ -f "/usr/bin/pacman" ]; then
    echo "pacman"
    return
  fi

  if [ -x "/usr/bin/apt-get" ] && [ -f "/usr/bin/apt-get" ]; then
    echo "apt-get"
    return
  fi

  if [ -x "/usr/bin/dnf" ] && [ -f "/usr/bin/dnf" ]; then
    echo "dnf"
    return
  fi

  if [ -x "/usr/bin/yum" ] && [ -f "/usr/bin/yum" ]; then
    echo "yum"
    return
  fi

  if [ -x "/usr/bin/zypper" ] && [ -f "/usr/bin/zypper" ]; then
    echo "zypper"
    return
  fi

  if [ -x "/usr/bin/eopkg" ] && [ -f "/usr/bin/eopkg" ]; then
    echo "eopkg"
    return
  fi

  echo "unknown package manager"
  exit
}

pause_if_tty() {
  if [ -t 0 ]; then
    [ -n "$1" ] && printf "%s" "$1"
    read -r _ || true
  fi
}

install_dependencies() {
  if command -v sudo >/dev/null 2>&1 \
    && command -v curl >/dev/null 2>&1 \
    && command -v unzip >/dev/null 2>&1 \
    && command -v bash >/dev/null 2>&1; then
    return 0
  fi
  case $PKG_MANAGER in
  "pacman")
    pacman -Sy
    pacman -S --noconfirm sudo
    sudo pacman -S --noconfirm curl unzip bash
    ;;
  "apt-get")
    apt-get update
    apt-get install -y sudo
    sudo apt-get install -y curl unzip bash nautilus-admin
    ;;
  "dnf")
    dnf install -y sudo
    enable_epel
    sudo dnf install -y curl unzip bash
    ;;
  "yum")
    yum install -y sudo
    enable_epel
    sudo yum install -y curl unzip bash
    ;;
  "zypper")
    zypper install -y sudo
    sudo zypper install -y curl unzip bash
    ;;

  "eopkg")
    eopkg update-repo
    eopkg install -y sudo
    sudo eopkg install -y curl unzip bash
    ;;
  esac
}

detect_desktop_environment() {
  detected=""
  f=""

  for f in /usr/share/xsessions/*.desktop /usr/share/wayland-sessions/*.desktop; do
    [ -f "$f" ] || continue

    # GNOME及衍生桌面
    if grep -Eqi "^Exec=.*gnome-session.*pantheon|^DesktopNames=.*pantheon" "$f" 2>/dev/null; then
      echo "pantheon"
      return
    elif grep -Eqi "^Exec=.*gnome-session" "$f" 2>/dev/null \
      && grep -Eqi "^DesktopNames=zorin:GNOME" "$f" 2>/dev/null; then
      echo "zorin"
      return
    elif grep -Eqi "^Exec=.*gnome-session" "$f" 2>/dev/null \
      && grep -Eqi "^DesktopNames=pop:GNOME" "$f" 2>/dev/null; then
      echo "cosmic"
      return
    elif grep -Eqi "^Exec=.*gnome-session" "$f" 2>/dev/null \
      && grep -Eqi "^Name=AnduinOS" "$f" 2>/dev/null; then
      echo "anduin"
      return
    elif grep -Eqi "^Exec=.*gnome-session" "$f" 2>/dev/null \
      && grep -Eqi "^DesktopNames=.*GNOME" "$f" 2>/dev/null; then
      if ! echo " $detected " | grep -q " gnome "; then detected="$detected gnome"; fi
    fi

    # 主流完整桌面
    if grep -Eqi "^Exec=.*startplasma|^DesktopNames=.*plasma" "$f" 2>/dev/null; then
      if ! echo " $detected " | grep -q " kde "; then detected="$detected kde"; fi
    fi
    if grep -Eqi "^Exec=.*xfce4-session|^DesktopNames=.*xfce" "$f" 2>/dev/null; then
      if ! echo " $detected " | grep -q " xfce "; then detected="$detected xfce"; fi
    fi
    if grep -Eqi "^Exec=.*startlxde|^Exec=.*lxsession.*LXDE|^DesktopNames=.*lxde" "$f" 2>/dev/null; then
      if ! echo " $detected " | grep -q " lxde "; then detected="$detected lxde"; fi
    fi
    if grep -Eqi "^Exec=.*startlxqt|^Exec=.*lxqt-session|^DesktopNames=.*lxqt" "$f" 2>/dev/null; then
      if ! echo " $detected " | grep -q " lxqt "; then detected="$detected lxqt"; fi
    fi
    if grep -Eqi "^Exec=.*cinnamon-session|^DesktopNames=.*cinnamon" "$f" 2>/dev/null; then
      if ! echo " $detected " | grep -q " cinnamon "; then detected="$detected cinnamon"; fi
    fi
    if grep -Eqi "^Exec=.*mate-session|^DesktopNames=.*mate" "$f" 2>/dev/null; then
      if ! echo " $detected " | grep -q " mate "; then detected="$detected mate"; fi
    fi
    if grep -Eqi "^Exec=.*budgie-desktop|^DesktopNames=.*budgie" "$f" 2>/dev/null; then
      if ! echo " $detected " | grep -q " budgie "; then detected="$detected budgie"; fi
    fi
    if grep -Eqi "^Exec=.*startdde|^DesktopNames=.*deepin" "$f" 2>/dev/null; then
      if ! echo " $detected " | grep -q " deepin "; then detected="$detected deepin"; fi
    fi
    if grep -Eqi "^Exec=.*ukui-session|^DesktopNames=.*ukui" "$f" 2>/dev/null; then
      if ! echo " $detected " | grep -q " ukui "; then detected="$detected ukui"; fi
    fi
    if grep -Eqi "^Exec=.*trinity|^DesktopNames=.*trinity" "$f" 2>/dev/null; then
      if ! echo " $detected " | grep -q " trinity "; then detected="$detected trinity"; fi
    fi
    if grep -Eqi "^Exec=.*cosmic|^DesktopNames=.*cosmic" "$f" 2>/dev/null; then
      if ! echo " $detected " | grep -q " cosmic "; then detected="$detected cosmic"; fi
    fi
    if grep -Eqi "^Exec=.*cutefish-session|^DesktopNames=.*cutefish" "$f" 2>/dev/null; then
      if ! echo " $detected " | grep -q " cutefish "; then detected="$detected cutefish"; fi
    fi
    if grep -Eqi "^Exec=.*enlightenment_start|^DesktopNames=.*enlightenment" "$f" 2>/dev/null; then
      if ! echo " $detected " | grep -q " enlightenment "; then detected="$detected enlightenment"; fi
    fi
    if grep -Eqi "^Exec=.*lumina|^DesktopNames=.*lumina" "$f" 2>/dev/null; then
      if ! echo " $detected " | grep -q " lumina "; then detected="$detected lumina"; fi
    fi
    if grep -Eqi "^Exec=.*cde|^DesktopNames=.*cde" "$f" 2>/dev/null; then
      if ! echo " $detected " | grep -q " cde "; then detected="$detected cde"; fi
    fi
    if grep -Eqi "^Exec=.*sugar|^DesktopNames=.*sugar" "$f" 2>/dev/null; then
      if ! echo " $detected " | grep -q " sugar "; then detected="$detected sugar"; fi
    fi

    # Wayland 合成器桌面
    if grep -Eqi "^Exec=.*sway|^DesktopNames=.*sway" "$f" 2>/dev/null; then
      if ! echo " $detected " | grep -q " sway "; then detected="$detected sway"; fi
    fi
    if grep -Eqi "^Exec=.*hyprland|^DesktopNames=.*hyprland" "$f" 2>/dev/null; then
      if ! echo " $detected " | grep -q " hyprland "; then detected="$detected hyprland"; fi
    fi
    if grep -Eqi "^Exec=.*river|^DesktopNames=.*river" "$f" 2>/dev/null; then
      if ! echo " $detected " | grep -q " river "; then detected="$detected river"; fi
    fi
    if grep -Eqi "^Exec=.*wayfire|^DesktopNames=.*wayfire" "$f" 2>/dev/null; then
      if ! echo " $detected " | grep -q " wayfire "; then detected="$detected wayfire"; fi
    fi
    if grep -Eqi "^Exec=.*weston|^DesktopNames=.*weston" "$f" 2>/dev/null; then
      if ! echo " $detected " | grep -q " weston "; then detected="$detected weston"; fi
    fi
    if grep -Eqi "^Exec=.*cage|^DesktopNames=.*cage" "$f" 2>/dev/null; then
      if ! echo " $detected " | grep -q " cage "; then detected="$detected cage"; fi
    fi
    if grep -Eqi "^Exec=.*hikari|^DesktopNames=.*hikari" "$f" 2>/dev/null; then
      if ! echo " $detected " | grep -q " hikari "; then detected="$detected hikari"; fi
    fi
    if grep -Eqi "^Exec=.*velox|^DesktopNames=.*velox" "$f" 2>/dev/null; then
      if ! echo " $detected " | grep -q " velox "; then detected="$detected velox"; fi
    fi
    if grep -Eqi "^Exec=.*way-cooler|^DesktopNames=.*way-cooler" "$f" 2>/dev/null; then
      if ! echo " $detected " | grep -q " way-cooler "; then detected="$detected way-cooler"; fi
    fi

    # 叠放窗口管理器
    if grep -Eqi "^Exec=.*openbox-session|^DesktopNames=.*openbox" "$f" 2>/dev/null; then
      if ! echo " $detected " | grep -q " openbox "; then detected="$detected openbox"; fi
    fi
    if grep -Eqi "^Exec=.*fluxbox|^DesktopNames=.*fluxbox" "$f" 2>/dev/null; then
      if ! echo " $detected " | grep -q " fluxbox "; then detected="$detected fluxbox"; fi
    fi
    if grep -Eqi "^Exec=.*icewm|^DesktopNames=.*icewm" "$f" 2>/dev/null; then
      if ! echo " $detected " | grep -q " icewm "; then detected="$detected icewm"; fi
    fi
    if grep -Eqi "^Exec=.*jwm|^DesktopNames=.*jwm" "$f" 2>/dev/null; then
      if ! echo " $detected " | grep -q " jwm "; then detected="$detected jwm"; fi
    fi
    if grep -Eqi "^Exec=.*fvwm|^DesktopNames=.*fvwm" "$f" 2>/dev/null; then
      if ! echo " $detected " | grep -q " fvwm "; then detected="$detected fvwm"; fi
    fi
    if grep -Eqi "^Exec=.*wmaker|^DesktopNames=.*(wmaker|Window Maker)" "$f" 2>/dev/null; then
      if ! echo " $detected " | grep -q " wmaker "; then detected="$detected wmaker"; fi
    fi
    if grep -Eqi "^Exec=.*afterstep|^DesktopNames=.*afterstep" "$f" 2>/dev/null; then
      if ! echo " $detected " | grep -q " afterstep "; then detected="$detected afterstep"; fi
    fi
    if grep -Eqi "^Exec=.*blackbox|^DesktopNames=.*blackbox" "$f" 2>/dev/null; then
      if ! echo " $detected " | grep -q " blackbox "; then detected="$detected blackbox"; fi
    fi
    if grep -Eqi "^Exec=.*pekwm|^DesktopNames=.*pekwm" "$f" 2>/dev/null; then
      if ! echo " $detected " | grep -q " pekwm "; then detected="$detected pekwm"; fi
    fi
    # 平铺窗口管理器
    if grep -Eqi "^Exec=.*\bi3(\s|$)|^DesktopNames=.*i3" "$f" 2>/dev/null; then
      if ! echo " $detected " | grep -q " i3 "; then detected="$detected i3"; fi
    fi
    if grep -Eqi "^Exec=.*bspwm|^DesktopNames=.*bspwm" "$f" 2>/dev/null; then
      if ! echo " $detected " | grep -q " bspwm "; then detected="$detected bspwm"; fi
    fi
    if grep -Eqi "^Exec=.*awesome|^DesktopNames=.*awesome" "$f" 2>/dev/null; then
      if ! echo " $detected " | grep -q " awesome "; then detected="$detected awesome"; fi
    fi
    if grep -Eqi "^Exec=.*qtile|^DesktopNames=.*qtile" "$f" 2>/dev/null; then
      if ! echo " $detected " | grep -q " qtile "; then detected="$detected qtile"; fi
    fi
    if grep -Eqi "^Exec=.*dwm|^DesktopNames=.*dwm" "$f" 2>/dev/null; then
      if ! echo " $detected " | grep -q " dwm "; then detected="$detected dwm"; fi
    fi
    if grep -Eqi "^Exec=.*ratpoison|^DesktopNames=.*ratpoison" "$f" 2>/dev/null; then
      if ! echo " $detected " | grep -q " ratpoison "; then detected="$detected ratpoison"; fi
    fi
    if grep -Eqi "^Exec=.*flwm|^DesktopNames=.*flwm" "$f" 2>/dev/null; then
      if ! echo " $detected " | grep -q " flwm "; then detected="$detected flwm"; fi
    fi
    if grep -Eqi "^Exec=.*twm|^DesktopNames=.*twm" "$f" 2>/dev/null; then
      if ! echo " $detected " | grep -q " twm "; then detected="$detected twm"; fi
    fi
    if grep -Eqi "^Exec=.*metacity|^DesktopNames=.*metacity" "$f" 2>/dev/null; then
      if ! echo " $detected " | grep -q " metacity "; then detected="$detected metacity"; fi
    fi
    # 移动/收敛窗口管理器
    if grep -Eqi "^Exec=.*lomiri|^DesktopNames=.*lomiri" "$f" 2>/dev/null; then
      if ! echo " $detected " | grep -q " lomiri "; then detected="$detected lomiri"; fi
    fi
    if grep -Eqi "^Exec=.*xmonad|^DesktopNames=.*xmonad" "$f" 2>/dev/null; then
      if ! echo " $detected " | grep -q " xmonad "; then detected="$detected xmonad"; fi
    fi
    if grep -Eqi "^Exec=.*herbstluftwm|^DesktopNames=.*herbstluftwm" "$f" 2>/dev/null; then
      if ! echo " $detected " | grep -q " herbstluftwm "; then detected="$detected herbstluftwm"; fi
    fi
    if grep -Eqi "^Exec=.*spectrwm|^DesktopNames=.*spectrwm" "$f" 2>/dev/null; then
      if ! echo " $detected " | grep -q " spectrwm "; then detected="$detected spectrwm"; fi
    fi
    if grep -Eqi "^Exec=.*notion|^Exec=.*ion3|^DesktopNames=.*notion" "$f" 2>/dev/null; then
      if ! echo " $detected " | grep -q " notion "; then detected="$detected notion"; fi
    fi
    # 实验/教育/非主流窗口管理器
    if grep -Eqi "^Exec=.*mezzo|^DesktopNames=.*mezzo" "$f" 2>/dev/null; then
      if ! echo " $detected " | grep -q " mezzo "; then detected="$detected mezzo"; fi
    fi
    if grep -Eqi "^Exec=.*etoile|^DesktopNames=.*etoile" "$f" 2>/dev/null; then
      if ! echo " $detected " | grep -q " etoile "; then detected="$detected etoile"; fi
    fi
    if grep -Eqi "^Exec=.*ede|^DesktopNames=.*ede" "$f" 2>/dev/null; then
      if ! echo " $detected " | grep -q " ede "; then detected="$detected ede"; fi
    fi
  done

  echo "$detected"
}

get_all_users() {
  users="/root"
  while IFS=: read -r _ _ uid _ _ home shell; do
    if [ "$uid" -ge 1000 ] && [ -d "$home" ] && ! echo "$shell" | grep -Eq 'nologin|false'; then
      users="$users $home"
    fi
  done </etc/passwd
  echo "$users"
}

enable_epel() {
  if [ -f /etc/os-release ]; then
    ID=$(grep -w "^ID=" /etc/os-release | cut -d'=' -f2 | tr -d '"')
  fi

  case "$ID" in
  fedora)
    :
    ;;
  rocky | almalinux | centos | rhel)
    if command -v dnf >/dev/null 2>&1; then
      sudo dnf install -y epel-release
      sudo dnf upgrade -y epel-release
      sudo dnf config-manager --set-enabled crb || sudo dnf config-manager --set-enabled powertools
    fi
    ;;
  *)
    :
    ;;
  esac
}

install_standard_fonts() {
  case $PKG_MANAGER in
  "pacman")
    sudo pacman -S --noconfirm noto-fonts-cjk
    ;;
  "apt-get")
    sudo apt-get install -y fonts-noto fonts-noto-cjk fonts-noto-mono
    ;;
  "dnf")
    sudo dnf install -y google-noto-sans-fonts google-noto-serif-fonts google-noto-sans-cjk-ttc-fonts
    ;;
  "yum")
    sudo yum install -y google-noto-sans-fonts google-noto-serif-fonts google-noto-sans-cjk-ttc-fonts google-noto-sans-simplified-chinese-fonts
    ;;
  "zypper")
    sudo zypper install -y noto-fonts noto-fonts-cjk
    ;;
  "eopkg")
    sudo eopkg install -y fonts-noto
    ;;
  esac

  for user_home in $ALL_USERS; do
    [ -d "$user_home" ] || continue

    user_name="$(stat -c '%U' "$user_home" 2>/dev/null)"
    if [ -z "$user_name" ]; then
      echo "Warning: Cannot get owner for $user_home, skipping..."
      continue
    fi
    user_group="$(stat -c '%G' "$user_home" 2>/dev/null)"
    if [ -z "$user_group" ]; then
      echo "Warning: Cannot get group for $user_home, skipping..."
      continue
    fi

    for desktop in $DESKTOPS; do
      case $desktop in
      "gnome")
        if [ -f /etc/os-release ] && grep -q "ubuntu" /etc/os-release; then
          sudo apt-get install -y language-pack-gnome-zh-hans
        fi
        sudo -u "$user_name" env HOME="$user_home" gsettings reset-recursively org.gnome.desktop.interface 2>/dev/null
        sudo -u "$user_name" env HOME="$user_home" gsettings reset-recursively org.gnome.desktop.wm.preferences 2>/dev/null
        ;;
      esac
    done
  done
}

install_chinese_locale() {
  has_standard_desktop=false
  has_other_desktop=false
  for desktop in $DESKTOPS; do
    case $desktop in
    afterstep | awesome | blackbox | bspwm | budgie | cinnamon | dwm | enlightenment | fluxbox | flwm | fvwm | gnome | i3 | icewm | jwm | kde | lomiri | lxde | lxqt | mate | metacity | openbox | pekwm | qtile | ratpoison | sway | twm | ukui | wayfire | wmaker | xfce)
      has_standard_desktop=true
      ;;
    *)
      if [ -n "$desktop" ]; then
        has_other_desktop=true
      fi
      ;;
    esac
  done

  if [ -z "$DESKTOPS" ]; then
    has_standard_desktop=true
  fi

  if [ "$has_standard_desktop" = false ] || [ "$has_other_desktop" = true ]; then
    return
  fi

  case $PKG_MANAGER in
  "pacman")
    sudo pacman -S --noconfirm glibc
    ;;
  "apt-get")
    if [ -f /etc/debian_version ]; then
      if grep -q "ubuntu" /etc/os-release; then
        sudo apt-get install -y language-pack-zh-hans language-pack-zh-hans-base
      else
        sudo apt-get install -y locales
      fi
    else
      sudo apt-get install -y locales
    fi
    ;;
  "dnf")
    sudo dnf install -y langpacks-zh_CN glibc-langpack-zh
    ;;
  "yum")
    sudo yum install -y langpacks-zh_CN glibc-langpack-zh
    ;;
  "zypper")
    sudo zypper install -y glibc-locale
    ;;

  "eopkg")
    sudo eopkg install -y glibc
    ;;
  esac

  if command -v locale-gen >/dev/null 2>&1; then
    if [ -f /etc/locale.gen ]; then
      sudo sed -i 's/^# *zh_CN.UTF-8 UTF-8/zh_CN.UTF-8 UTF-8/' /etc/locale.gen
      if ! grep -q "^zh_CN.UTF-8 UTF-8" /etc/locale.gen; then
        echo "zh_CN.UTF-8 UTF-8" | sudo tee -a /etc/locale.gen
      fi
      sudo locale-gen
    else
      sudo locale-gen zh_CN.UTF-8
    fi

    if command -v update-locale >/dev/null 2>&1; then
      sudo update-locale LANG=zh_CN.UTF-8
      sudo update-locale LC_ALL=zh_CN.UTF-8
    else
      sudo tee /etc/locale.conf >/dev/null <<EOF
LANG=zh_CN.UTF-8
LC_ALL=zh_CN.UTF-8
EOF
    fi
  else
    case $PKG_MANAGER in
    "pacman" | "eopkg")
      sudo tee /etc/locale.conf >/dev/null <<EOF
LANG=zh_CN.UTF-8
LC_ALL=zh_CN.UTF-8
EOF
      ;;
    "dnf" | "yum" | "zypper")
      if command -v localectl >/dev/null 2>&1; then
        sudo localectl set-locale LANG=zh_CN.UTF-8
      else
        sudo tee /etc/locale.conf >/dev/null <<EOF
LANG=zh_CN.UTF-8
LC_ALL=zh_CN.UTF-8
EOF
      fi
      ;;
    esac
  fi
}

install_chinese_ime() {
  for desktop in $DESKTOPS; do
    case $desktop in
    "gnome" | "anduin" | "cosmic" | "pantheon")
      case $PKG_MANAGER in
      "pacman")
        sudo pacman -S --noconfirm gnome-shell gnome-tweaks gnome-extensions-app
        ;;
      "apt-get")
        if [ -f /etc/os-release ] && grep -qi ubuntu /etc/os-release; then
          sudo apt-get install -y gnome-shell gnome-tweaks gnome-shell-extension-manager
        else
          sudo apt-get install -y gnome-shell gnome-tweaks gnome-extensions-app
        fi
        ;;
      "dnf" | "yum")
        sudo "${PKG_MANAGER}" install -y gnome-shell gnome-tweaks gnome-extensions-app
        ;;
      "zypper")
        sudo zypper install -y gnome-shell gnome-tweaks gnome-extensions-app
        ;;
      "eopkg")
        sudo eopkg install -y gnome-shell gnome-tweaks gnome-extensions-app
        ;;
      esac

      user_name=""

      kimpanel_url="https://extensions.gnome.org/extension-data/kimpanelkde.org.v86.shell-extension.zip"
      kimpanel_temp="/tmp/kimpanel.zip"
      if curl -L -o "$kimpanel_temp" "$kimpanel_url"; then
        for user_home in $ALL_USERS; do
          [ -d "$user_home" ] || continue
          user_name="$(stat -c '%U' "$user_home" 2>/dev/null)"
          if command -v gnome-extensions >/dev/null 2>&1; then
            if sudo -u "$user_name" env HOME="$user_home" gnome-extensions install -f "$kimpanel_temp" >/dev/null 2>&1; then
              echo "Kimpanel extension has been installed for user $user_home"
            else
              echo "Failed to install Kimpanel extension for user $user_home"
              exit
            fi
          else
            echo "gnome-extensions command not found"
            exit
          fi
        done
        rm -f "$kimpanel_temp"
      else
        echo "Failed to download or install Kimpanel extension"
        exit
      fi

      hidetopbar_url="https://extensions.gnome.org/extension-data/hidetopbarmathieu.bidon.ca.v114.shell-extension.zip"
      hidetopbar_temp="/tmp/hidetopbar.zip"
      if curl -L -o "$hidetopbar_temp" "$hidetopbar_url"; then
        for user_home in $ALL_USERS; do
          [ -d "$user_home" ] || continue
          user_name="$(stat -c '%U' "$user_home" 2>/dev/null)"
          if command -v gnome-extensions >/dev/null 2>&1; then
            if sudo -u "$user_name" env HOME="$user_home" gnome-extensions install -f "$hidetopbar_temp"; then
              echo "Hide Top Bar extension has been installed for user $user_home"
            else
              echo "Failed to install Hide Top Bar extension for user $user_home"
              exit
            fi
          else
            echo "gnome-extensions command not found"
            exit
          fi
        done
        rm -f "$hidetopbar_temp"
      else
        echo "Failed to install Hide Top Bar extension"
        exit
      fi

      if [ "$desktop" = "gnome" ]; then
        tray_url="https://extensions.gnome.org/extension-data/appindicatorsupportrgcjonas.gmail.com.v53.shell-extension.zip"
        tray_temp="/tmp/systemtray.zip"
        if curl -L -o "$tray_temp" "$tray_url"; then
          for user_home in $ALL_USERS; do
            [ -d "$user_home" ] || continue
            user_name="$(stat -c '%U' "$user_home" 2>/dev/null)"
            if command -v gnome-extensions >/dev/null 2>&1; then
              if sudo -u "$user_name" env HOME="$user_home" gnome-extensions install -f "$tray_temp"; then
                echo "Installed system tray extension for user: $user_home"
              else
                echo "Failed to install system tray extension for user: $user_home"
                exit
              fi
            else
              echo "gnome-extensions command not found"
              exit
            fi
          done
          rm -f "$tray_temp"
        else
          echo "System tray extension installation failed"
          exit
        fi

        addtodesktop_url="https://extensions.gnome.org/extension-data/add-to-desktoptommimon.github.com.v10.shell-extension.zip"
        addtodesktop_temp="/tmp/addtodesktop.zip"
        if curl -L -o "$addtodesktop_temp" "$addtodesktop_url"; then
          for user_home in $ALL_USERS; do
            [ -d "$user_home" ] || continue
            user_name="$(stat -c '%U' "$user_home" 2>/dev/null)"
            if command -v gnome-extensions >/dev/null 2>&1; then
              if sudo -u "$user_name" env HOME="$user_home" gnome-extensions install -f "$addtodesktop_temp"; then
                echo "Installed Add to Desktop extension for user: $user_home"
              else
                echo "Failed to install Add to Desktop extension for user: $user_home"
                exit
              fi
            else
              echo "gnome-extensions command not found"
              exit
            fi
          done
          rm -f "$addtodesktop_temp"
        else
          echo "Add to Desktop extension installation failed"
          exit
        fi
      fi

      ;;
    esac
  done

  case $PKG_MANAGER in
  "pacman")
    sudo pacman -S --noconfirm fcitx5-im fcitx5-rime
    ;;
  "apt-get")
    sudo apt-get install -y fcitx5 fcitx5-config-qt fcitx5-rime im-config
    im-config -n fcitx5
    ;;
  "dnf")
    sudo dnf install -y ibus ibus-libpinyin ibus-chewing ibus-table-chinese ibus-table-quick ibus-table-wubi
    return 0
    ;;
  "yum")
    sudo yum install -y ibus ibus-libpinyin ibus-chewing ibus-table-chinese ibus-table-quick ibus-table-wubi
    return 0
    ;;
  "zypper")
    sudo zypper install -y fcitx5 fcitx5-rime
    ;;
  "eopkg")
    sudo eopkg install -y fcitx5 fcitx5-rime
    ;;
  *)
    echo "Unsupported system"
    exit
    ;;
  esac

  if command -v fcitx5 >/dev/null 2>&1; then
    fcitx_exec="/usr/bin/fcitx5 -r"
  elif command -v fcitx >/dev/null 2>&1; then
    fcitx_exec="/usr/bin/fcitx -r"
  elif command -v flatpak >/dev/null 2>&1 && flatpak info org.fcitx.Fcitx5 >/dev/null 2>&1; then
    fcitx_exec="$(command -v flatpak) run org.fcitx.Fcitx5 -r"
  else
    echo "Fcitx not found"
    exit
  fi

  rimescim_url="https://raw.githubusercontent.com/jaman21/rime/main/rimesc.zip"
  rimescim_temp="/tmp/rimesc.zip"
  if curl -L -o "$rimescim_temp" "$rimescim_url"; then
    rimescim_status="true"
  else
    echo "Rimescim extension installation failed"
    rimescim_status="false"
    pause_if_tty "Press enter to continue..."
  fi

  for user_home in $ALL_USERS; do
    [ -d "$user_home" ] || continue

    user_name="$(stat -c '%U' "$user_home" 2>/dev/null)"
    if [ -z "$user_name" ]; then
      echo "Warning: Cannot get owner for $user_home, skipping..."
      pause_if_tty "Press enter to continue..."
      continue
    fi
    user_group="$(stat -c '%G' "$user_home" 2>/dev/null)"
    if [ -z "$user_group" ]; then
      echo "Warning: Cannot get group for $user_home, skipping..."
      pause_if_tty "Press enter to continue..."
      continue
    fi
    user_uid="$(id -u "$user_name" 2>/dev/null)" || user_uid=""
    if [ -z "$user_uid" ]; then
      echo "Error: Cannot resolve uid for user $user_name"
      exit 1
    fi

    if [ "$rimescim_status" = "true" ]; then
      rimescim_dir="$user_home/.local/share/fcitx5/rime"
      if [ -d "$rimescim_dir" ]; then
        sudo rm -rf "$rimescim_dir"
      fi
      sudo -u "$user_name" mkdir -p "$rimescim_dir"
      if sudo -u "$user_name" unzip -o "$rimescim_temp" -d "$rimescim_dir" >/dev/null 2>&1; then
        echo "Installed rimescim extension for user: $user_home"
      else
        echo "Failed to install rimescim extension for user: $user_home"
        pause_if_tty "Press enter to continue..."
      fi
    fi

    user_systemd_dir="$user_home/.config/systemd/user"
    user_systemd_wants="$user_systemd_dir/graphical-session.target.wants"
    sudo -u "$user_name" env HOME="$user_home" mkdir -p "$user_systemd_wants"
    sudo -u "$user_name" env HOME="$user_home" tee "$user_systemd_dir/fcitx5.service" >/dev/null <<EOF
[Unit]
Description=Fcitx Input Method
After=graphical-session-pre.target
PartOf=graphical-session.target

[Service]
Type=simple
ExecStart=$fcitx_exec
Restart=on-failure
RestartSec=2

[Install]
WantedBy=graphical-session.target
EOF
    sudo chmod 644 "$user_systemd_dir/fcitx5.service"
    sudo chown "$user_name:$user_group" "$user_systemd_dir/fcitx5.service"
    sudo -u "$user_name" env HOME="$user_home" ln -sfn "../fcitx5.service" "$user_systemd_wants/fcitx5.service"
    if command -v loginctl >/dev/null 2>&1; then
      sudo loginctl enable-linger "$user_name" || {
        echo "Error: loginctl enable-linger failed for $user_name"
        exit 1
      }
    fi
    sudo systemctl start "user@${user_uid}.service" || {
      echo "Error: failed to start user@${user_uid}.service (required for systemctl --user during install)"
      exit 1
    }
    if ! sudo -u "$user_name" env \
      XDG_RUNTIME_DIR="/run/user/$user_uid" \
      HOME="$user_home" \
      systemctl --user daemon-reload; then
      echo "Error: systemctl --user daemon-reload failed for $user_name"
      exit 1
    fi
    # if command -v systemd-analyze >/dev/null 2>&1; then
    #     if ! sudo -u "$user_name" env \
    #         XDG_RUNTIME_DIR="/run/user/$user_uid" \
    #         HOME="$user_home" \
    #         systemd-analyze --user verify "$user_systemd_dir/fcitx5.service"; then
    #         echo "Error: systemd-analyze --user verify failed for $user_systemd_dir/fcitx5.service"
    #         exit 1
    #     fi
    # fi
    if ! sudo -u "$user_name" env \
      XDG_RUNTIME_DIR="/run/user/$user_uid" \
      HOME="$user_home" \
      systemctl --user enable fcitx5.service; then
      echo "Error: systemctl --user enable fcitx5.service failed for $user_name"
      exit 1
    fi
  done

  [ -f "$rimescim_temp" ] && rm -f "$rimescim_temp"
}

main() {
  PKG_MANAGER=$(detect_package_manager)
  install_dependencies
  DESKTOPS=$(detect_desktop_environment)
  ALL_USERS=$(get_all_users)

  if [ -n "$DESKTOPS" ]; then
    echo "Desktop environment: $DESKTOPS"
    pause_if_tty "Press enter to continue..."
  fi

  install_standard_fonts
  install_chinese_locale

  if [ -n "$DESKTOPS" ]; then
    install_chinese_ime
  fi

  echo "Installation completed! Please restart your desktop environment to apply changes."
  echo "Note: System language has been changed to Chinese. Please restart to see the changes."
}

main "$@"
