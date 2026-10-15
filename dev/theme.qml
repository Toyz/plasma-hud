import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import org.kde.ksvg as KSvg
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PC3
import org.kde.plasma.extras as PlasmaExtras

// Preview of the helba-hud theme with real Plasma controls (what stock popups use).
Window {
    id: w
    width: 520
    height: 600
    visible: true
    color: "#1b1f2a"

    KSvg.FrameSvgItem {
        id: dlg
        x: 20; y: 20
        width: 480; height: 560
        imagePath: "dialogs/background"
    }
    ColumnLayout {
        x: dlg.x + dlg.margins.left
        y: dlg.y + dlg.margins.top
        width: dlg.width - dlg.margins.left - dlg.margins.right
        spacing: 10

        PlasmaExtras.PlasmoidHeading {
            Layout.fillWidth: true
            contentItem: RowLayout {
                Kirigami.Heading { text: "Volume"; level: 2; Layout.fillWidth: true }
                PC3.ToolButton { icon.name: "configure" }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Kirigami.Icon { source: "audio-volume-high"; implicitWidth: 22; implicitHeight: 22 }
            PC3.Slider { Layout.fillWidth: true; from: 0; to: 100; value: 64 }
            PC3.Label { text: "64%" }
        }
        Repeater {
            model: ["Speakers (Katana V2X)", "HDMI / DisplayPort 2", "Headset"]
            PC3.ItemDelegate {
                required property int index
                required property string modelData
                Layout.fillWidth: true
                text: modelData
                icon.name: "audio-card"
                highlighted: index === 0
                hoverEnabled: true
            }
        }
        RowLayout {
            PC3.Switch { checked: true; text: "Bluetooth" }
            PC3.Switch { checked: false; text: "Airplane mode" }
        }
        RowLayout {
            PC3.Button { text: "Connect"; icon.name: "network-connect" }
            PC3.Button { text: "Cancel" }
            PC3.ToolButton { text: "Details"; icon.name: "view-more" }
        }
        PC3.TextField { Layout.fillWidth: true; placeholderText: "Password" }
        PC3.CheckBox { text: "Remember"; checked: true }
        PlasmaExtras.Highlight { Layout.fillWidth: true; Layout.preferredHeight: 34; hovered: false }
    }
    Timer {
        interval: 2500; running: true
        onTriggered: w.contentItem.grabToImage(r => { r.saveToFile("/home/helba/projects/plasma-hud/dev/theme.png"); Qt.quit(); })
    }
}
