import QtQuick
import QtQuick.Layouts

// Net link: download and upload history.
// Part of the HUD popup, and a desktop widget of its own (org.helba.hudtile).
Section {
    id: c
    title: "NET LINK"
    tag: "04 // " + (c.hud.iface || "--")

    RowLayout {
        spacing: 12
        Legend { tone: c.hud.accent; text: "↓ " + c.hud.rate(c.hud.netDown) }
        Legend { tone: c.hud.accent2; text: "↑ " + c.hud.rate(c.hud.netUp) }
        Item { Layout.fillWidth: true }
        Text {
            text: "peak " + c.hud.rate(netSpark.scaleMax / 1.2)
            color: c.hud.dim
            font.family: c.hud.monoFont
            font.pixelSize: 8
        }
    }
    Sparkline {
        id: netSpark
        Layout.fillWidth: true
        Layout.preferredHeight: 66
        Layout.fillHeight: true
        values: c.hud.netDownHist
        values2: c.hud.netUpHist
        capacity: c.hud.histLen
        maxValue: 0
        color: c.hud.accent
        color2: c.hud.accent2
        glow: c.hud.glow
        visible: c.visible
    }

    component Legend: Row {
        property color tone
        property alias text: lt.text
        spacing: 5
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 8
            height: 2
            color: parent.tone
        }
        Text {
            id: lt
            color: c.hud.text
            font.family: c.hud.monoFont
            font.pixelSize: 10
        }
    }
}
