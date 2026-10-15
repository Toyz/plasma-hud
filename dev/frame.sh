#!/bin/sh
# Preview a helba window frame: ./frame.sh [helba-world|helba-world-light] [out.png]
cd "$(dirname "$0")"
theme=${1:-helba-world}; out=${2:-$PWD/frame-$theme.png}
rc=../packages/aurorae/$theme/${theme}rc
text=$(sed -n 's/^ActiveTextColor=//p' "$rc" | awk -F, '{ printf "#%02x%02x%02x", $1, $2, $3 }')
texti=$(sed -n 's/^InactiveTextColor=//p' "$rc" | awk -F, '{ printf "#%02x%02x%02x", $1, $2, $3 }')
sed -e "s|__THEME__|$theme|" -e "s|__OUT__|$out|" -e "s|__TEXT__|$text|" -e "s|__TEXTI__|$texti|" frame.tpl > .frame.qml
QT_FORCE_STDERR_LOGGING=1 timeout 30 qml6 ./.frame.qml 2>&1 | grep -v -e QProcess
rm -f .frame.qml
