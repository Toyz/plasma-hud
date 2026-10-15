#!/usr/bin/env python3
"""Render the Helba World logout screen the way ksmserver-logout-greeter loads it.

    python3 dev/logout_preview.py [all|halt|reboot|logout] [0|1 = dark|light] out.png

The greeter hands the screen context properties (ShutdownType, sdtype, maysd,
spdMethods, ...); QML mocks cannot declare capitalised names, so they are set from
Python on a real QQmlContext.
"""
import os
import shutil
import sys
import tempfile

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
from PyQt6.QtCore import QTimer, QUrl
from PyQt6.QtGui import QGuiApplication
from PyQt6.QtQuick import QQuickView

mode = sys.argv[1] if len(sys.argv) > 1 else "all"
light = sys.argv[2] == "1" if len(sys.argv) > 2 else False
out = sys.argv[3] if len(sys.argv) > 3 else f"logout-{mode}-{int(light)}.png"
sd = {"all": -1, "logout": 0, "reboot": 1, "halt": 2}[mode]

tmp = tempfile.mkdtemp()
src = os.path.join(os.path.dirname(os.path.abspath(__file__)), "../packages/lookandfeel/contents/logout/Logout.qml")
text = open(src).read().replace("readonly property bool light: Kirigami.Theme.backgroundColor.hslLightness > 0.5",
                                f"readonly property bool light: {'true' if light else 'false'}")
open(os.path.join(tmp, "Logout.qml"), "w").write(text)
open(os.path.join(tmp, "run.qml"), "w").write("""import QtQuick
Item {
    width: 1600; height: 900
    Image { anchors.fill: parent; source: "file:///home/helba/Pictures/wally/wallhaven-w5dod6.png"; fillMode: Image.PreserveAspectCrop }
    Loader { anchors.fill: parent; source: "Logout.qml" }
}
""")

app = QGuiApplication(sys.argv[:1])
view = QQuickView()
ctx = view.rootContext()
ctx.setContextProperty("ShutdownType", {"ShutdownTypeDefault": -1, "ShutdownTypeNone": 0, "ShutdownTypeReboot": 1, "ShutdownTypeHalt": 2})
ctx.setContextProperty("sdtype", sd)
ctx.setContextProperty("maysd", True)
ctx.setContextProperty("canLogout", True)
ctx.setContextProperty("spdMethods", {"SuspendState": True, "HibernateState": True, "HybridSuspendState": False})
ctx.setContextProperty("softwareUpdatePending", False)
ctx.setContextProperty("rebootToFirmwareSetup", False)
ctx.setContextProperty("isUefi", True)
ctx.setContextProperty("rebootToBootLoaderMenu", False)
ctx.setContextProperty("rebootToBootLoaderEntry", "")
view.setSource(QUrl.fromLocalFile(os.path.join(tmp, "run.qml")))
for e in view.errors():
    print(e.toString())
view.resize(1600, 900)
view.show()


def shoot():
    view.grabWindow().save(out)
    shutil.rmtree(tmp)
    app.quit()


QTimer.singleShot(3500, shoot)
app.exec()
