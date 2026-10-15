import QtQuick
import QtQuick.Window
import org.kde.ksvg as KSvg

// Preview a helba Aurorae theme with KSvg (what Aurorae draws with): an active and an
// inactive window, plus a maximized title band. sed __THEME__ / __OUT__ (see frame.sh).
Window {
    id: w
    width: 1200
    height: 640
    visible: true
    color: "#3a3f4a"

    readonly property string dir: "/home/helba/projects/plasma-hud/packages/aurorae/__THEME__/"
    readonly property int pad: 14
    readonly property int border: 4
    readonly property int top: 32
    readonly property var rc: ({ text: "__TEXT__", textInactive: "__TEXTI__" })

    // Grabs skip the window color: paint a desktop-ish backdrop to judge alpha against.
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#4a5263" }
            GradientStop { position: 1.0; color: "#2b2f3a" }
        }
    }

    component Win: Item {
        id: win
        property bool active: true
        property string title: "konsole: ~/projects/plasma-hud"
        width: 520
        height: 300
        KSvg.FrameSvgItem {
            anchors.fill: parent
            imagePath: w.dir + "decoration.svg"
            prefix: win.active ? "decoration" : "decoration-inactive"
        }
        // client area
        Rectangle {
            x: w.pad + w.border
            y: w.pad + w.top
            width: win.width - 2 * (w.pad + w.border)
            height: win.height - y - w.pad - w.border
            color: "#1b1e26"
            Text { x: 10; y: 8; text: "helba@seshat ~ $"; color: "#cfd6e4"; font.family: "Hack"; font.pixelSize: 13 }
        }
        Text {
            x: w.pad + 10
            width: win.width - 2 * w.pad - 20
            y: w.pad + 5
            height: 22
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: win.title
            color: win.active ? w.rc.text : w.rc.textInactive
            font.pixelSize: 13
        }
        Row {
            x: win.width - w.pad - 10 - width
            y: w.pad + 5
            spacing: 6
            Repeater {
                model: ["minimize", "maximize", "close"]
                KSvg.FrameSvgItem {
                    required property string modelData
                    required property int index
                    width: 22; height: 22
                    imagePath: w.dir + modelData + ".svg"
                    prefix: !win.active ? "inactive" : (win.active && index === 2 && win.hoverClose) ? "hover" : "active"
                }
            }
        }
        Row {
            x: w.pad + 10
            y: w.pad + 5
            KSvg.FrameSvgItem { width: 22; height: 22; imagePath: w.dir + "alldesktops.svg"; prefix: win.active ? "active" : "inactive" }
        }
        property bool hoverClose: false
    }

    Win { x: 40; y: 30; active: false; title: "Dolphin: Pictures" }
    Win { x: 330; y: 120; active: true; hoverClose: true }
    Item {
        x: 40; y: 470; width: 1120; height: 28
        KSvg.FrameSvgItem { anchors.fill: parent; imagePath: w.dir + "decoration.svg"; prefix: "decoration-maximized"; enabledBorders: KSvg.FrameSvg.NoBorder }
        Text { anchors.centerIn: parent; text: "Maximized: System Settings"; color: w.rc.text; font.pixelSize: 13 }
    }
    Row {
        x: 40; y: 540; spacing: 14
        Repeater {
            model: ["active", "hover", "pressed", "inactive", "deactivated"]
            Row {
                required property string modelData
                spacing: 4
                Repeater {
                    model: ["close", "minimize", "maximize", "restore", "alldesktops", "keepabove", "keepbelow"]
                    KSvg.FrameSvgItem {
                        required property string modelData
                        width: 22; height: 22
                        imagePath: w.dir + modelData + ".svg"
                        prefix: parent.modelData
                    }
                }
            }
        }
    }

    Timer {
        interval: 1500; running: true
        onTriggered: w.contentItem.grabToImage(r => { r.saveToFile("__OUT__"); Qt.quit(); })
    }
}
