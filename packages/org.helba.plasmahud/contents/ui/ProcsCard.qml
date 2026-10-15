import QtQuick
import QtQuick.Layouts

// Processes: the top processes by CPU, grouped by name (from hudprobe).
// Part of the HUD popup, and a desktop widget of its own (org.helba.hudtile).
Section {
    id: c
    property int rows: 7
    title: "PROCESSES"
    tag: "05 // " + (c.hud.probe.procs || "--") + " PID"

    RowLayout {
        Layout.fillWidth: true
        spacing: 6
        TableHead { text: "##"; Layout.preferredWidth: 16 }
        TableHead { text: "NAME"; Layout.fillWidth: true }
        TableHead { text: "CPU%"; Layout.preferredWidth: 96; horizontalAlignment: Text.AlignRight }
        TableHead { text: "RSS"; Layout.preferredWidth: 44; horizontalAlignment: Text.AlignRight }
    }
    Repeater {
        model: c.hud.procs.slice(0, c.rows)
        RowLayout {
            id: proc
            required property var modelData
            required property int index
            Layout.fillWidth: true
            spacing: 6
            readonly property real maxCpu: Math.max(1, c.hud.procs.length ? c.hud.procs[0].cpu : 1)

            Text {
                Layout.preferredWidth: 16
                text: c.hud.pad2(proc.index + 1)
                color: proc.index === 0 ? c.hud.accent2 : c.hud.dim
                font.family: c.hud.monoFont
                font.pixelSize: 10
            }
            Text {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: proc.modelData.name + (proc.modelData.count > 1 ? "  x" + proc.modelData.count : "")
                color: proc.index === 0 ? c.hud.text : c.hud.alpha(c.hud.text, 0.8)
                font.family: c.hud.monoFont
                font.pixelSize: 11
            }
            Item {
                Layout.preferredWidth: 96
                implicitHeight: 14
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 44
                    height: 3
                    color: c.hud.alpha(c.hud.accent, 0.12)
                    Rectangle {
                        width: parent.width * Math.min(1, proc.modelData.cpu / proc.maxCpu)
                        height: parent.height
                        color: proc.index === 0 ? c.hud.accent2 : c.hud.accent
                    }
                }
                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: proc.modelData.cpu.toFixed(1)
                    color: c.hud.text
                    font.family: c.hud.monoFont
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                }
            }
            Text {
                Layout.preferredWidth: 44
                horizontalAlignment: Text.AlignRight
                text: c.hud.bytes(proc.modelData.rss)
                color: c.hud.dim
                font.family: c.hud.monoFont
                font.pixelSize: 10
            }
        }
    }
    Text {
        visible: c.hud.procs.length === 0
        text: c.hud.probeOk ? "Gathering…" : "Probe offline"
        color: c.hud.probeOk ? c.hud.dim : c.hud.crit
        font.family: c.hud.monoFont
        font.pixelSize: 10
    }

    component TableHead: Text {
        color: c.hud.gold
        font.family: c.hud.serifFont
        font.capitalization: Font.SmallCaps
        font.pixelSize: 10
        font.letterSpacing: 1.5
    }
}
