#!/usr/bin/env python3
"""Render the HelbaWorld GTK 3 theme with real widgets in an offscreen window.

    python3 dev/gtk_preview.py out.png

Run as GTK_THEME=HelbaWorld python3 dev/gtk_preview.py out.png, with the theme linked
into ~/.local/share/themes; the user's KDE colors apply as in any app. Menus are separate popup
windows, so a vertical menubar stands in for one, with an item forced to hover.
"""
import os
import sys

import gi
gi.require_version("Gtk", "3.0")
from gi.repository import Gtk, Gdk, GLib

out = sys.argv[1]
# Run with GTK_THEME=HelbaWorld (theme linked into ~/.local/share/themes) so GTK loads
# it exactly as an app would, with the user's KDE colors on top.
win = Gtk.OffscreenWindow()
outer = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=16)
outer.set_border_width(16)
win.add(outer)

left = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
outer.pack_start(left, False, False, 0)
nb = Gtk.Notebook()
for t in ["Root Town", "Chaos Gate"]:
    nb.append_page(Gtk.Label(label=" "), Gtk.Label(label=t))
left.pack_start(nb, False, False, 0)
row = Gtk.Box(spacing=8)
row.pack_start(Gtk.Button(label="Warp"), False, False, 0)
b = Gtk.Button(label="Default")
b.get_style_context().add_class("suggested-action")
row.pack_start(b, False, False, 0)
sw = Gtk.Switch()
sw.set_active(True)
row.pack_start(sw, False, False, 0)
left.pack_start(row, False, False, 0)
e = Gtk.Entry()
e.set_placeholder_text("Enter a keyword...")
left.pack_start(e, False, False, 0)
pb = Gtk.ProgressBar()
pb.set_fraction(0.42)
left.pack_start(pb, False, False, 0)
cb = Gtk.CheckButton(label="Pause when covered")
cb.set_active(True)
left.pack_start(cb, False, False, 0)

store = Gtk.ListStore(str)
for n in ["Documents", "Downloads", "Pictures", "Projects", "Music"]:
    store.append([n])
tv = Gtk.TreeView(model=store)
tv.append_column(Gtk.TreeViewColumn("Places", Gtk.CellRendererText(), text=0))
tv.get_selection().select_path(Gtk.TreePath(1))
scroll = Gtk.ScrolledWindow()
scroll.set_size_request(260, 150)
scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.ALWAYS)
scroll.add(tv)
left.pack_start(scroll, False, False, 0)

mb = Gtk.MenuBar()
mb.set_pack_direction(Gtk.PackDirection.TTB)
mb.get_style_context().add_class("menu")
for i, n in enumerate(["Open", "Open With", "Copy Location", "Rename", "Move to Trash", "Properties"]):
    mi = Gtk.MenuItem(label=n)
    if i == 2:
        mi.set_state_flags(Gtk.StateFlags.PRELIGHT, False)
    mb.append(mi)
outer.pack_start(mb, False, False, 0)

win.show_all()


def shoot():
    pix = win.get_pixbuf()
    pix.savev(out, "png", [], [])
    Gtk.main_quit()
    return False


GLib.timeout_add(600, shoot)
Gtk.main()
