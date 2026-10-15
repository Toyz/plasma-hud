#!/bin/sh
# Render the HUD offscreen-ish with live sensors: ./render.sh <palette> [out.png]
cd "$(dirname "$0")"
pal=${1:-0}; out=${2:-$PWD/shot$pal.png}
sed -e "s/__MODE__/${MODE:-0}/" -e "s/__PAL__/$pal/" -e "s|__OUT__|$out|" harness.tpl > .h$pal.qml
QT_FORCE_STDERR_LOGGING=1 timeout 40 qml6 ./.h$pal.qml 2>&1 | grep -v QProcess
rm -f .h$pal.qml
