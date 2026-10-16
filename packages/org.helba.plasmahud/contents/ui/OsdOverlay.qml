import QtQuick
import QtQuick.Window
import org.kde.kirigami as Kirigami
import org.kde.layershell as LayerShell
import org.kde.plasma.workspace.dbus as DBus

// The .hack OSD for volume, brightness and the other on-screen notices. Plasma's own
// OSD keeps running (it is what emits osdProgress / osdText on D-Bus; the Helba Gate
// KWin effect keeps its window invisible) and this draws the notice instead: a glass
// plate near the bottom of the active screen with the icon in a gold diamond, the
// label and value in serif, and a bar of diamond cells lit cyan to the level (gold
// past 100 %, for volume overdrive).
Item {
    id: osd

    required property QtObject hud
    property string icon: ""
    property string label: ""
    property real value: 0          // 0..max
    property real maximum: 100
    property bool progress: false
    property bool shown: false

    visible: false

    function prettyName(iconName) {
        const n = String(iconName);
        if (n.indexOf("audio-volume") === 0) return "Volume";
        if (n.indexOf("microphone") === 0) return "Microphone";
        if (n.indexOf("brightness") >= 0) return n.indexOf("keyboard") >= 0 ? "Keyboard light" : "Brightness";
        return "";
    }
    function showProgress(iconName, v, max, extra) {
        icon = iconName;
        value = v;
        maximum = Math.max(1, max);
        label = extra || prettyName(iconName);
        progress = true;
        pop();
    }
    function showText(iconName, text) {
        // The desktop-name notice: the gate warp already announces areas.
        if (!iconName) return;
        icon = iconName;
        label = text;
        progress = false;
        pop();
    }
    function pop() {
        shown = true;
        hideSoon.restart();
    }
    Timer {
        id: hideSoon
        interval: 1600
        onTriggered: osd.shown = false
    }

    DBus.SignalWatcher {
        busType: DBus.BusType.Session
        service: "org.kde.plasmashell"
        path: "/org/kde/osdService"
        iface: "org.kde.osdService"
        function dbusosdProgress(iconName, v, max, extra) { osd.showProgress(iconName, v, max, extra); }
        function dbusosdText(iconName, text) { osd.showText(iconName, text); }
    }

    Window {
        id: win
        width: 420
        height: 132
        color: "transparent"
        flags: Qt.FramelessWindowHint | Qt.WindowTransparentForInput
        visible: plate.opacity > 0

        LayerShell.Window.scope: "org.helba.osd"
        LayerShell.Window.layer: LayerShell.Window.LayerOverlay
        LayerShell.Window.anchors: LayerShell.Window.AnchorBottom
        LayerShell.Window.margins.bottom: 110
        LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityNone
        LayerShell.Window.exclusionZone: -1
        LayerShell.Window.wantsToBeOnActiveScreen: true

        Item {
            id: plate
            anchors.fill: parent
            anchors.margins: 10
            opacity: osd.shown ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: osd.shown ? 120 : 380 } }
            transform: Translate { y: osd.shown ? 0 : 8; Behavior on y { NumberAnimation { duration: 200 } } }

            HackFrame {
                anchors.fill: parent
                hud: osd.hud
                radius: 6
                stud: 6
            }

            // Icon in a gold diamond.
            Item {
                id: badge
                x: 16
                anchors.verticalCenter: parent.verticalCenter
                width: 64
                height: 64
                Rectangle {
                    anchors.centerIn: parent
                    width: 44
                    height: 44
                    rotation: 45
                    color: osd.hud.alpha(osd.hud.cyan, 0.08)
                    border.width: 1.4
                    border.color: osd.hud.gold
                }
                Kirigami.Icon {
                    anchors.centerIn: parent
                    width: 30
                    height: 30
                    source: osd.icon
                }
            }

            Column {
                anchors.left: badge.right
                anchors.leftMargin: 14
                anchors.right: parent.right
                anchors.rightMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                spacing: 9

                Row {
                    width: parent.width
                    Text {
                        width: parent.width - pct.width
                        text: osd.label
                        elide: Text.ElideRight
                        color: osd.hud.gold
                        font.family: osd.hud.serifFont
                        font.capitalization: Font.SmallCaps
                        font.letterSpacing: 2
                        font.pixelSize: 16
                    }
                    Text {
                        id: pct
                        visible: osd.progress
                        text: Math.round(osd.value) + "%"
                        color: osd.hud.ink
                        font.family: osd.hud.serifFont
                        font.pixelSize: 16
                    }
                }

                // Diamond cells: cyan to the level, gold past 100 %.
                Row {
                    visible: osd.progress
                    spacing: 3
                    readonly property int cells: 20
                    readonly property real full: Math.min(osd.value, osd.maximum) / Math.max(osd.maximum, 100) * cells
                    Repeater {
                        model: parent.cells
                        Item {
                            required property int index
                            readonly property real lit: Math.max(0, Math.min(1, parent.full - index))
                            readonly property bool over: (index + 1) / parent.cells * Math.max(osd.maximum, 100) > 100
                            width: 11
                            height: 14
                            Rectangle {
                                anchors.centerIn: parent
                                width: 8
                                height: 8
                                rotation: 45
                                color: parent.lit > 0 ? osd.hud.alpha(parent.over ? osd.hud.gold : osd.hud.cyan, 0.35 + 0.65 * parent.lit)
                                                      : osd.hud.alpha(osd.hud.inkDim, 0.18)
                                border.width: 1
                                border.color: osd.hud.alpha(parent.over ? osd.hud.gold : osd.hud.cyan, parent.lit > 0 ? 0.9 : 0.25)
                                Behavior on color { ColorAnimation { duration: 90 } }
                            }
                        }
                    }
                }
            }
        }
    }
}
