import QtQuick
import QtQuick.Shapes

// The World's window frame: midnight glass with a soft top light, a gold rule with a
// faint inner echo, and diamond studs at the corners.
Item {
    id: f

    required property QtObject hud
    property real radius: 6
    property real stud: 7
    property real trim: 0.75

    Rectangle {
        anchors.fill: parent
        radius: f.radius
        gradient: Gradient {
            GradientStop { position: 0.0; color: f.hud.glassTop }
            GradientStop { position: 0.35; color: f.hud.glassBottom }
            GradientStop { position: 1.0; color: f.hud.glassBottom }
        }
        border.width: 1
        border.color: f.hud.alpha(f.hud.gold, f.trim)
    }
    Rectangle {
        anchors.fill: parent
        anchors.margins: 3
        radius: Math.max(0, f.radius - 2)
        color: "transparent"
        border.width: 1
        border.color: f.hud.alpha(f.hud.gold, f.trim * 0.25)
    }
    // Top light.
    Rectangle {
        x: f.radius * 2
        width: parent.width - f.radius * 4
        y: 1
        height: 1
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.5; color: f.hud.alpha(f.hud.ink, 0.35) }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }
    Repeater {
        model: 4
        Rectangle {
            required property int index
            width: f.stud
            height: f.stud
            rotation: 45
            color: f.hud.gold
            border.width: 1
            border.color: f.hud.alpha(f.hud.glassBottom, 0.9)
            x: (index % 2 ? f.width : 0) - width / 2
            y: (index < 2 ? 0 : f.height) - height / 2
        }
    }
}
