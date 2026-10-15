#!/bin/sh
# Render one wallpaper effect: ./wall.sh <effect> [image-url] [ms]
cd "$(dirname "$0")"
fx=${1:-0}; img=${2:-}; ms=${3:-3500}
sed -e "s|__FX__|$fx|" -e "s|__IMG__|$img|" -e "s|__MS__|$ms|" -e "s|__OUT__|$PWD/wall$fx${img:+i}.png|" wall.tpl > .w$fx.qml
QT_FORCE_STDERR_LOGGING=1 timeout 40 qml6 ./.w$fx.qml 2>&1 | grep -v -e QProcess -e "legacy metadata" -e PlasmaWindowManagement
rm -f .w$fx.qml
