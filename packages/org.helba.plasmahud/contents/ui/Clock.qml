import QtQuick
import QtQuick.Effects

// HH:MM in glowing mono with a blinking colon and a seconds sweep underneath.
// Hover swaps the time for the date.
Item {
    id: clk

    required property QtObject hud
    property real size: 30
    signal clicked

    property date now: new Date()
    Timer {
        interval: 1000
        running: clk.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: clk.now = new Date()
    }

    implicitWidth: Math.max(time.implicitWidth, date.implicitWidth)
    implicitHeight: size

    Row {
        id: time
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -1
        opacity: hover.containsMouse ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: 160 } }
        layer.enabled: clk.hud.glow > 0
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: clk.hud.cyan
            shadowBlur: 0.45
            shadowOpacity: clk.hud.glow
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
        }
        component Digits: Text {
            color: clk.hud.text
            font.family: clk.hud.serifFont
            font.pixelSize: Math.round(clk.size * 0.64)
            font.weight: Font.Medium
        }
        Digits { text: Qt.formatTime(clk.now, "HH") }
        Digits {
            text: ":"
            color: clk.hud.gold
            opacity: clk.now.getSeconds() % 2 ? 0.35 : 1
        }
        Digits { text: Qt.formatTime(clk.now, "mm") }
    }

    // Seconds sweep.
    Rectangle {
        anchors.left: time.left
        anchors.bottom: parent.bottom
        width: time.width * clk.now.getSeconds() / 59
        height: 1
        color: clk.hud.gold
        opacity: hover.containsMouse ? 0 : 0.8
        Behavior on width { NumberAnimation { duration: 900; easing.type: Easing.Linear } }
    }

    Text {
        id: date
        anchors.centerIn: parent
        opacity: hover.containsMouse ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 160 } }
        text: Qt.formatDate(clk.now, "dddd d MMMM")
        color: clk.hud.text
        font.family: clk.hud.serifFont
        font.capitalization: Font.SmallCaps
        font.pixelSize: Math.max(8, Math.round(clk.size * 0.42))
        font.letterSpacing: 1.5
    }

    MouseArea {
        id: hover
        hoverEnabled: true
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: clk.clicked()
    }
}
