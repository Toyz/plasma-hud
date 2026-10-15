#!/bin/sh
# Render every HUD Tile card: MODE=1 ./tiles.sh [image-url] [out.png]
cd "$(dirname "$0")"
img=${1:-}; out=${2:-$PWD/tiles.png}
sed -e "s|__MODE__|${MODE:-0}|" -e "s|__IMG__|$img|" -e "s|__OUT__|$out|" tiles.tpl > .tiles.qml
QT_FORCE_STDERR_LOGGING=1 timeout 40 qml6 ./.tiles.qml 2>&1 | grep -v -e QProcess -e "different thread"
rm -f .tiles.qml
