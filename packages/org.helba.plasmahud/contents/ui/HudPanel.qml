import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import org.kde.ksysguard.sensors as Sensors

// The floating HUD: header, gauges, core matrix, traces, process table, system block, command deck.
FocusScope {
    id: p

    required property QtObject hud
    signal closeRequested
    signal command(string cmd, bool detached)

    readonly property int cut: 18
    property real boot: 1

    width: 820
    height: col.implicitHeight + 64
    focus: true
    Keys.onEscapePressed: closeRequested()

    function play() {
        boot = 0;
        bootAnim.restart();
    }

    NumberAnimation {
        id: bootAnim
        target: p
        property: "boot"
        from: 0
        to: 1
        duration: 1000
        easing.type: Easing.OutQuad
    }

    // ------------------------------------------------------------ chrome

    // Inset so the corner studs stay inside the popup window, with a gap above the bar.
    HackFrame {
        anchors.fill: parent
        anchors.margins: 8
        anchors.bottomMargin: 16
        hud: p.hud
        radius: 8
        stud: 8
    }

    // ----------------------------------------------------------- content

    ColumnLayout {
        id: col
        x: 28
        y: 28
        width: p.width - 56
        spacing: 10

        // Header.
        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            opacity: Math.min(1, p.boot * 4)

            ColumnLayout {
                spacing: 3
                RowLayout {
                    spacing: 10
                    Text {
                        text: "◆"
                        color: p.hud.cyan
                        font.pixelSize: 12
                    }
                    Text {
                        text: "The World"
                        color: p.hud.gold
                        font.family: p.hud.serifFont
                        font.capitalization: Font.SmallCaps
                        font.pixelSize: 26
                        font.letterSpacing: 4
                    }
                    Text {
                        Layout.alignment: Qt.AlignBottom
                        bottomPadding: 4
                        text: "status"
                        color: p.hud.inkDim
                        font.family: p.hud.serifFont
                        font.italic: true
                        font.pixelSize: 12
                    }
                }
                Text {
                    text: (p.hud.user ? p.hud.user + "@" : "") + p.hud.hostname
                        + "  ·  " + p.hud.osName + "  ·  " + p.hud.kernel
                    color: p.hud.inkDim
                    font.family: p.hud.serifFont
                    font.italic: true
                    font.pixelSize: 11
                }
            }

            Item { Layout.fillWidth: true }

            ColumnLayout {
                spacing: 0
                Text {
                    Layout.alignment: Qt.AlignRight
                    text: Qt.formatTime(p.hud.now, "HH:mm:ss")
                    color: p.hud.ink
                    font.family: p.hud.serifFont
                    font.pixelSize: 28
                    font.weight: Font.Medium
                }
                Text {
                    Layout.alignment: Qt.AlignRight
                    text: Qt.formatDate(p.hud.now, "dddd d MMMM yyyy") + "  ·  up " + p.hud.uptimeLong(p.hud.uptime).toLowerCase()
                    color: p.hud.inkDim
                    font.family: p.hud.serifFont
                    font.italic: true
                    font.pixelSize: 11
                }
            }
        }

        // Gauges.
        GaugesCard {
            hud: p.hud
            boot: p.boot
            order: 1
            Layout.fillWidth: true
        }

        // Per-thread matrix.
        CoresCard {
            hud: p.hud
            boot: p.boot
            order: 2
            Layout.fillWidth: true
        }

        // Traces.
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            LoadCard {
                hud: p.hud
                boot: p.boot
                order: 3
                Layout.fillWidth: true
                Layout.preferredWidth: 1
            }
            NetCard {
                hud: p.hud
                boot: p.boot
                order: 3.5
                Layout.fillWidth: true
                Layout.preferredWidth: 1
            }
        }

        // Processes + system.
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            ProcsCard {
                hud: p.hud
                boot: p.boot
                order: 4
                Layout.fillWidth: true
                Layout.preferredWidth: 58
                Layout.alignment: Qt.AlignTop
            }
            SystemCard {
                hud: p.hud
                boot: p.boot
                order: 4.5
                Layout.fillWidth: true
                Layout.preferredWidth: 42
                Layout.alignment: Qt.AlignTop
            }
        }

        // Command deck.
        DeckCard {
            hud: p.hud
            boot: p.boot
            Layout.fillWidth: true
            Layout.topMargin: 2
            onCommand: (cmd, detached) => p.command(cmd, detached)
        }

        // Ticker.
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 14
            clip: true
            opacity: Math.max(0, Math.min(1, p.boot * 6 - 4.5))

            Rectangle {
                width: parent.width
                height: 1
                color: p.hud.alpha(p.hud.accent, 0.2)
            }
            Row {
                id: ticker
                y: 3
                Repeater {
                    model: 2
                    Text {
                        text: p.hud.tickerText
                        color: p.hud.alpha(p.hud.gold, 0.6)
                        font.family: p.hud.serifFont
                        font.italic: true
                        font.pixelSize: 10
                    }
                }
                NumberAnimation on x {
                    running: p.visible
                    from: 0
                    to: -ticker.width / 2
                    duration: Math.max(8000, ticker.width * 25)
                    loops: Animation.Infinite
                }
            }
        }
    }
}
