import QtQuick
import QtQuick.Effects

// The launcher emblem: the Twilight Bracelet. A gold ring with three studs and a
// data-cyan core that turns a quarter on hover.
Item {
    id: btn

    required property QtObject hud
    property real size: 30
    signal clicked

    readonly property real ring: Math.round(size * 0.66)
    implicitWidth: size
    implicitHeight: size

    Item {
        id: emblem
        anchors.centerIn: parent
        width: btn.ring
        height: btn.ring
        layer.enabled: btn.hud.glow > 0
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: btn.hud.gold
            shadowBlur: ma.containsMouse ? 0.7 : 0.35
            shadowOpacity: btn.hud.glow
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
        }

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "transparent"
            border.width: 1.5
            border.color: btn.hud.gold
        }
        // Studs at 12, 4 and 8 o'clock.
        Repeater {
            model: 3
            Rectangle {
                required property int index
                readonly property real a: (-90 + index * 120) * Math.PI / 180
                width: Math.max(3, Math.round(btn.ring * 0.16))
                height: width
                rotation: 45
                color: btn.hud.gold
                x: emblem.width / 2 + Math.cos(a) * emblem.width / 2 - width / 2
                y: emblem.height / 2 + Math.sin(a) * emblem.height / 2 - height / 2
            }
        }
        Rectangle {
            anchors.centerIn: parent
            width: Math.round(btn.ring * 0.34)
            height: width
            rotation: ma.containsMouse ? 135 : 45
            Behavior on rotation { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
            color: btn.hud.cyan
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: btn.clicked()
    }
}
