#!/bin/sh
# Switch the login screen between SDDM (Helba World theme) and Plasma Login Manager
# (Plasma 6.8's stock login, which takes no themes). Takes effect at the next boot.
#
#   dev/login-manager.sh sddm          use SDDM with the Helba World theme
#   dev/login-manager.sh plasmalogin   go back to Plasma Login Manager (the safe revert)
#   dev/login-manager.sh               show which one is active
#
# Stuck at a black or broken login? Ctrl+Alt+F3, log in, then:
#   ~/projects/plasma-hud/dev/login-manager.sh plasmalogin --reboot
set -eu

current=$(basename "$(readlink -f /etc/systemd/system/display-manager.service 2>/dev/null)" .service)
want=${1:-}
reboot=${2:-}

case "$want" in
    "")
        echo "login manager: ${current:-none}"
        exit 0 ;;
    sddm|plasmalogin) ;;
    *)
        echo "usage: $0 [sddm|plasmalogin] [--reboot]" >&2
        exit 2 ;;
esac

if [ "$want" = "$current" ]; then
    echo "login manager is already $want"
else
    command -v "$want" >/dev/null 2>&1 || { echo "$want is not installed" >&2; exit 1; }
    if [ "$want" = sddm ] && [ ! -d /usr/share/sddm/themes/helba-world ]; then
        echo "note: the Helba World SDDM theme is not installed (./installer.sh --sddm)"
    fi
    echo "switching login manager: ${current:-none} -> $want (sudo)"
    [ -n "$current" ] && sudo systemctl disable "$current.service"
    sudo systemctl enable "$want.service"
    echo "done: $want starts at the next boot"
fi

if [ "$reboot" = "--reboot" ]; then
    sudo systemctl reboot
fi
