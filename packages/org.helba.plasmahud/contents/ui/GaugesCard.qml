import QtQuick
import QtQuick.Layouts

// Telemetry: CPU / GPU / VRAM / memory ring gauges.
// Part of the HUD popup, and a desktop widget of its own (org.helba.hudtile).
Section {
    id: c
    title: "TELEMETRY"
    tag: "01 // " + c.hud.sampleRate + "MS"

    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 4
        readonly property real reveal: Math.max(0, Math.min(1, c.boot * 2 - 0.3))

        RingGauge {
            hud: c.hud
            Layout.fillWidth: true
            Layout.preferredHeight: 148
        Layout.fillHeight: true
            label: "CPU"
            value: c.hud.cpu
            peak: c.hud.cpuPeak
            reveal: parent.reveal
            spinning: c.visible
            sub1: c.hud.cpuTemp > 0 ? c.hud.cpuTemp.toFixed(1) + "°C" : "--"
            sub2: (c.hud.cpuFreq / 1000).toFixed(2) + " GHZ"
            color: c.hud.level(c.hud.cpu)
        }
        RingGauge {
            hud: c.hud
            Layout.fillWidth: true
            Layout.preferredHeight: 148
        Layout.fillHeight: true
            label: "GPU"
            value: c.hud.gpu
            peak: c.hud.gpuPeak
            reveal: parent.reveal
            spinning: c.visible
            sub1: Math.round(c.hud.gpuTemp) + "°C  " + Math.round(c.hud.gpuPower) + "W"
            sub2: Math.round(c.hud.gpuFreq) + " MHZ"
        }
        RingGauge {
            hud: c.hud
            Layout.fillWidth: true
            Layout.preferredHeight: 148
        Layout.fillHeight: true
            label: "VRAM"
            value: c.hud.vram
            peak: c.hud.vramPeak
            reveal: parent.reveal
            spinning: c.visible
            sub1: c.hud.bytes(c.hud.vramUsed) + " / " + c.hud.bytes(c.hud.vramTotal)
            sub2: c.hud.gpuShortName
        }
        RingGauge {
            hud: c.hud
            Layout.fillWidth: true
            Layout.preferredHeight: 148
        Layout.fillHeight: true
            label: "MEM"
            value: c.hud.mem
            peak: c.hud.memPeak
            reveal: parent.reveal
            spinning: c.visible
            sub1: c.hud.bytes(c.hud.memUsed) + " / " + c.hud.bytes(c.hud.memTotal)
            sub2: "SWAP " + Math.round(c.hud.swap) + "%"
        }
    }
}
