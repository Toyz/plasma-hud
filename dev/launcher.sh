#!/bin/sh
# Render the launcher with real kicker models: ./launcher.sh [category] [query] [out.png]
cd "$(dirname "$0")"
cat=${1:-0}; q=${2:-}; out=${3:-$PWD/launcher$cat${q:+-q}.png}
sed -e "s|__MODE__|${MODE:-0}|" -e "s|__CAT__|$cat|" -e "s|__QUERY__|$q|g" -e "s|__OUT__|$out|" launcher.tpl > .launcher.qml
QT_FORCE_STDERR_LOGGING=1 timeout 40 qml6 ./.launcher.qml 2>&1 | grep -v -e QProcess -e "legacy metadata" -e PlasmaWindowManagement -e "different thread" -e "overrides a member"
rm -f .launcher.qml
