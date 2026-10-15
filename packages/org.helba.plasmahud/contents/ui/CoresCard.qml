import QtQuick
import QtQuick.Layouts
import org.kde.ksysguard.sensors as Sensors

// Core matrix: one bar per CPU thread, grouped by eight.
// Part of the HUD popup, and a desktop widget of its own (org.helba.hudtile).
Section {
    id: c
    title: "CORE MATRIX"
    tag: "02 // " + c.hud.threads + "T"

    Item {
        id: matrix
        Layout.fillWidth: true
        Layout.preferredHeight: 50
        Layout.fillHeight: true
        readonly property int n: Math.max(1, c.hud.threads)
        readonly property int groups: Math.ceil(n / 8)
        readonly property real gap: 2
        readonly property real groupGap: 8
        readonly property real cw: (width - (n - 1) * gap - (groups - 1) * groupGap) / n

        Repeater {
            model: c.hud.threads
            Item {
                id: cell
                required property int index
                x: index * (matrix.cw + matrix.gap) + Math.floor(index / 8) * matrix.groupGap
                width: matrix.cw
                height: matrix.height - 12

                Sensors.Sensor {
                    id: core
                    sensorId: "cpu/cpu" + cell.index + "/usage"
                    enabled: c.hud.open
                    updateRateLimit: c.hud.sampleRate
                }
                readonly property real v: Math.max(0, Math.min(100, core.value || 0))
                readonly property color tone: c.hud.level(v)

                Rectangle {
                    anchors.fill: parent
                    color: c.hud.alpha(c.hud.accent, 0.06)
                }
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: Math.max(1, parent.height * cell.v / 100 * Math.min(1, c.boot * 1.5))
                    color: c.hud.alpha(cell.tone, 0.75)
                    Behavior on height { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
                    Rectangle {
                        width: parent.width
                        height: 1
                        color: cell.tone
                    }
                }
            }
        }
        // LED striping over the bars.
        Canvas {
            width: parent.width
            height: parent.height - 12
            renderTarget: Canvas.FramebufferObject
            onWidthChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                ctx.fillStyle = "rgba(5,7,12,0.85)";
                for (let y = 3; y < height; y += 4) ctx.fillRect(0, y, width, 1);
            }
        }
        Repeater {
            model: matrix.groups
            Text {
                required property int index
                x: index * 8 * (matrix.cw + matrix.gap) + index * matrix.groupGap
                y: matrix.height - 10
                text: "C" + c.hud.pad2(index * 8)
                color: c.hud.dim
                font.family: c.hud.monoFont
                font.pixelSize: 8
            }
        }
    }
}
