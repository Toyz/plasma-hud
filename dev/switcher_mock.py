#!/usr/bin/env python3
"""Turn a KWin window switcher's main.qml into something qml6 can render offscreen.

    python3 dev/switcher_mock.py packages/helba-roster/contents/ui/main.qml out.qml MODE

KWin's own QML types (TabBoxSwitcher, WindowThumbnail) only exist inside KWin, so they
are swapped for plain items with a mock window list; the Plasma dialog becomes an item
holding its mainItem. MODE 1 forces the light palette.
"""
import re
import sys

src, out, mode = sys.argv[1], sys.argv[2], sys.argv[3]
s = open(src).read()
s = s.replace("import org.kde.kwin as KWin\n", "")
# KWin's switcher owns currentIndex; the mock declares it, so drop the layout's write-back.
s = re.sub(r"\n\s*currentIndex: \(instantiator\.object[^\n]*", "", s)
s = s.replace("KWin.TabBoxSwitcher {", """Item {
    width: 1600
    height: 900
    property int currentIndex: 1
    property rect screenGeometry: Qt.rect(0, 0, 1600, 900)
    property var model: MockWindows {}""", 1)
s = re.sub(r"KWin\.WindowThumbnail \{", "Rectangle { property string wId; color: \"#2a3150\"; Text { anchors.centerIn: parent; text: \"live window\"; color: \"#8d98b6\" }", s)
s = s.replace("PlasmaCore.Dialog {", """Item {
        property Item mainItem
        property int location
        property int flags
        property int backgroundHints
        signal sceneGraphError
        Component.onCompleted: {
            mainItem.parent = tabBox;
            mainItem.x = Qt.binding(() => x);
            mainItem.y = Qt.binding(() => y);
        }""")
if mode == "1":
    s = s.replace("readonly property bool light: Kirigami.Theme.backgroundColor.hslLightness > 0.5", "readonly property bool light: true")
elif mode == "2":
    s = s.replace("readonly property bool light: Kirigami.Theme.backgroundColor.hslLightness > 0.5", "readonly property bool light: false")
open(out, "w").write(s)
