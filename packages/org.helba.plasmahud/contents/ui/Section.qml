import QtQuick
import QtQuick.Layouts

// A titled pane inside the HUD: a quiet glass frame, a ◆ small-caps heading and a gold
// rule. Fades and lifts in on its turn when the HUD opens.
Item {
    id: s

    required property QtObject hud
    property string title: ""
    property string tag: ""
    property real order: 0
    property real boot: 1
    property real pad: 12
    default property alias content: body.data

    readonly property real _t: Math.max(0, Math.min(1, boot * 6 - order * 0.6))

    implicitHeight: header.height + body.implicitHeight + pad * 2 + 6
    opacity: _t
    transform: Translate { y: (1 - s._t) * 12 }

    HackFrame {
        anchors.fill: parent
        hud: s.hud
        radius: 4
        stud: 4
        trim: 0.4
    }

    RowLayout {
        id: header
        x: s.pad
        y: s.pad - 2
        width: s.width - s.pad * 2
        height: 16
        spacing: 7

        Text {
            text: "◆"
            color: s.hud.cyan
            font.pixelSize: 8
        }
        Text {
            text: s.title
            color: s.hud.gold
            font.family: s.hud.serifFont
            font.capitalization: Font.SmallCaps
            font.pixelSize: 13
            font.letterSpacing: 2
        }
        Rectangle {
            Layout.fillWidth: true
            height: 1
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: s.hud.alpha(s.hud.gold, 0.5) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }
        Text {
            text: s.tag
            color: s.hud.inkDim
            font.family: s.hud.serifFont
            font.italic: true
            font.pixelSize: 10
        }
    }

    ColumnLayout {
        id: body
        x: s.pad
        y: header.y + header.height + 8
        width: s.width - s.pad * 2
        // Grows with the section (desktop tiles); in the popup sections sit at their natural size.
        height: Math.max(implicitHeight, s.height - y - s.pad)
        spacing: 6
    }
}
