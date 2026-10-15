import QtQuick
import QtQuick.Layouts

// System: host, OS, kernel, Plasma, uptime, updates.
// Part of the HUD popup, and a desktop widget of its own (org.helba.hudtile).
Section {
    id: c
    title: "SYSTEM"
    tag: "06"

    Repeater {
        model: c.hud.sysRows
        RowLayout {
            required property var modelData
            Layout.fillWidth: true
            spacing: 6
            Text {
                Layout.preferredWidth: 52
                text: modelData[0]
                color: c.hud.gold
                font.family: c.hud.serifFont
                font.capitalization: Font.SmallCaps
                font.pixelSize: 11
                font.letterSpacing: 1
            }
            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideLeft
                text: modelData[1]
                color: modelData[2] ? c.hud.accent2 : c.hud.text
                font.family: c.hud.monoFont
                font.pixelSize: 11
            }
        }
    }
}
