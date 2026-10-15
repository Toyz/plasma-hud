#!/usr/bin/env python3
"""Render a Helba Kvantum theme offscreen with real Qt widgets.

    python3 dev/kvantum_preview.py HelbaWorld out.png

Uses a throwaway XDG_CONFIG_HOME so the user's Kvantum settings are untouched.
"""
import os
import sys
import tempfile

theme, out = sys.argv[1], sys.argv[2]
root = os.path.dirname(os.path.abspath(__file__)) + "/../packages/kvantum"
cfg = tempfile.mkdtemp()
os.makedirs(f"{cfg}/Kvantum")
os.symlink(os.path.abspath(f"{root}/{theme}"), f"{cfg}/Kvantum/{theme}")
with open(f"{cfg}/Kvantum/kvantum.kvconfig", "w") as f:
    f.write(f"[General]\ntheme={theme}\n")
os.environ["XDG_CONFIG_HOME"] = cfg
os.environ["QT_QPA_PLATFORM"] = "offscreen"

from PyQt6.QtCore import QPoint, Qt, QTimer
from PyQt6.QtGui import QAction, QImage, QPainter, QColor
from PyQt6.QtWidgets import (QApplication, QCheckBox, QComboBox, QHBoxLayout, QLabel, QLineEdit,
                             QMenu, QProgressBar, QPushButton, QSlider, QTabWidget, QVBoxLayout, QWidget,
                             QToolTip)

app = QApplication(["preview"])
app.setStyle("kvantum")

w = QWidget()
w.resize(520, 300)
lay = QVBoxLayout(w)
tabs = QTabWidget()
page = QWidget()
pl = QVBoxLayout(page)
row = QHBoxLayout()
row.addWidget(QPushButton("Warp"))
b = QPushButton("Default")
b.setDefault(True)
row.addWidget(b)
cb = QComboBox()
cb.addItems(["Δ Endless Iron Observatory", "Θ Whispering Iron Shrine"])
row.addWidget(cb)
pl.addLayout(row)
le = QLineEdit()
le.setPlaceholderText("Enter a keyword...")
pl.addWidget(le)
c = QCheckBox("Pause when covered")
c.setChecked(True)
pl.addWidget(c)
s = QSlider(Qt.Orientation.Horizontal)
s.setValue(60)
pl.addWidget(s)
pb = QProgressBar()
pb.setValue(42)
pl.addWidget(pb)
tabs.addTab(page, "Root Town")
tabs.addTab(QWidget(), "Chaos Gate")
lay.addWidget(tabs)

menu = QMenu()
for name in ["Open", "Open With", "Copy Location", None, "Rename", "Move to Trash", None, "Properties"]:
    if name is None:
        menu.addSeparator()
    elif name == "Open With":
        sub = menu.addMenu("Open With")
        sub.addAction("Kate")
        sub.addAction("Konsole")
    else:
        a = menu.addAction(name)
        if name == "Properties":
            a.setShortcut("Alt+Return")
check = QAction("Show Hidden Files", menu, checkable=True, checked=True)
menu.insertAction(menu.actions()[3], check)

tip = QLabel("Root Town: every app, sorted by use")
tip.setWindowFlags(Qt.WindowType.ToolTip)
tip.setForegroundRole(tip.foregroundRole())


def shoot():
    menu.popup(QPoint(0, 0))
    menu.setActiveAction(menu.actions()[2])
    tip.show()
    app.processEvents()
    W = w.grab()
    M = menu.grab()
    T = tip.grab()
    img = QImage(W.width() + M.width() + 60, max(W.height(), M.height()) + T.height() + 60, QImage.Format.Format_ARGB32)
    img.fill(QColor("#3a3f4a"))
    p = QPainter(img)
    p.drawPixmap(20, 20, W)
    p.drawPixmap(W.width() + 40, 20, M)
    p.drawPixmap(20, max(W.height(), M.height()) + 40, T)
    p.end()
    img.save(out)
    app.quit()


w.show()
QTimer.singleShot(400, shoot)
app.exec()
