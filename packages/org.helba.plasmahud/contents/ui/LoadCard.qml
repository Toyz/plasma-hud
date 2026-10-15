import QtQuick
import QtQuick.Layouts

// Load trace: CPU and GPU history.
// Part of the HUD popup, and a desktop widget of its own (org.helba.hudtile).
Section {
    id: c
    title: "LOAD TRACE"
    tag: "03"

    RowLayout {
        spacing: 12
        Legend { tone: c.hud.accent; text: "CPU " + c.hud.pad3(c.hud.cpu) + "%" }
        Legend { tone: c.hud.accent2; text: "GPU " + c.hud.pad3(c.hud.gpu) + "%" }
    }
    Sparkline {
        Layout.fillWidth: true
        Layout.preferredHeight: 66
        Layout.fillHeight: true
        values: c.hud.cpuHist
        values2: c.hud.gpuHist
        capacity: c.hud.histLen
        maxValue: 100
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
