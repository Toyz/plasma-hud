#!/bin/sh
# Render the islands bar over a wallpaper: ./bar.sh <palette> <image-url> [out.png]
cd "$(dirname "$0")"
pal=${1:-0}; img=${2:-}; out=${3:-$PWD/bar$pal.png}
sed -e "s|__MODE__|${MODE:-0}|" -e "s|__PAL__|$pal|" -e "s|__IMG__|$img|" -e "s|__OUT__|$out|" bar.tpl > .bar$pal.qml
QT_FORCE_STDERR_LOGGING=1 timeout 40 qml6 ./.bar$pal.qml 2>&1 | grep -v -e QProcess -e "legacy metadata" -e PlasmaWindowManagement -e "Unable to assign \[undefined\] to Plasma::Types::Location"
rm -f .bar$pal.qml
