import QtQuick
import "../lib/org/helba/hud"

// hudprobe's push socket (Rust QML module). Loaded through a Loader in Hud.qml so a
// missing or broken plugin degrades to the spawn path instead of breaking the widget.
ProbeSocket {}
