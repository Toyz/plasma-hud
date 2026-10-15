import QtQuick
import QtQuick.Shapes
import org.kde.kirigami as Kirigami

// Helba World login splash (.hack, The World). ksplash raises `stage` as the session
// starts (1 to about 5) and closes the splash when Plasma is up. The Chaos Gate sigil
// draws itself in step by step (outer ring, inner ring, hexagram, the twelve server
// glyphs) under "The World" and a line naming the stage; data cells rise behind it.
// It ends on the warp's midnight, where the desktop's gate-in arrival takes over.
Rectangle {
    id: root

    property int stage

    readonly property bool light: Kirigami.Theme.backgroundColor.hslLightness > 0.5
    readonly property color gold: light ? "#8a6418" : "#b8935a"
    readonly property color cyan: light ? "#14708a" : "#8fe3ff"
    readonly property color ink: light ? "#1a2033" : "#eaf0fb"
    readonly property color inkDim: light ? "#5a6380" : "#8d98b6"
    readonly property string serif: "Noto Serif"
    function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a); }

    color: light ? "#f6f0e0" : "#050a18"

    // 0..1, eased toward the stage.
    property real progress: Math.min(1, stage / 5)
    Behavior on progress { NumberAnimation { duration: 900; easing.type: Easing.OutCubic } }
    function ramp(x, a, b) { return Math.max(0, Math.min(1, (x - a) / (b - a))); }

    readonly property var lines: ["", "Opening the gate", "Connecting to The World", "Loading the field",
        "Gathering the party", "Entering The World"]

    // Data cells rising.
    Repeater {
        model: 36
        Rectangle {
            required property int index
            readonly property real seed: (index * 7919 % 97) / 97
            x: root.width * ((index * 37 % 100) / 100)
            width: 4 + seed * 6
            height: width
            color: root.cyan
            opacity: 0
            NumberAnimation on y {
                from: root.height + 20
                to: -20
                duration: 7000 + seed * 6000
                loops: Animation.Infinite
                // Wait for a real size: from/to are taken when the animation starts.
                running: root.height > 0
            }
            SequentialAnimation on opacity {
                loops: Animation.Infinite
                PauseAnimation { duration: seed * 3000 }
                NumberAnimation { to: 0.18 + seed * 0.25; duration: 1200 }
                NumberAnimation { to: 0; duration: 2400 }
            }
        }
    }

    // The sigil.
    Item {
        id: sigil
        readonly property real d: Math.min(root.width, root.height) * 0.42
        x: (root.width - d) / 2
        y: (root.height - d) / 2 - root.height * 0.04
        width: d
        height: d
        RotationAnimation on rotation { from: 0; to: 360; duration: 120000; loops: Animation.Infinite }

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: "transparent"
                strokeColor: root.gold
                strokeWidth: 2
                capStyle: ShapePath.FlatCap
                PathAngleArc {
                    centerX: sigil.d / 2; centerY: sigil.d / 2
                    radiusX: sigil.d / 2 - 2; radiusY: sigil.d / 2 - 2
                    startAngle: -90; sweepAngle: 360 * root.ramp(root.progress, 0.0, 0.4)
                }
            }
            ShapePath {
                fillColor: "transparent"
                strokeColor: root.alpha(root.gold, 0.6)
                strokeWidth: 1
                capStyle: ShapePath.FlatCap
                PathAngleArc {
                    centerX: sigil.d / 2; centerY: sigil.d / 2
                    radiusX: sigil.d * 0.36; radiusY: sigil.d * 0.36
                    startAngle: 90; sweepAngle: -360 * root.ramp(root.progress, 0.2, 0.6)
                }
            }
        }
        Shape {
            id: hex
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            opacity: root.ramp(root.progress, 0.45, 0.75)
            rotation: -sigil.rotation * 2
            readonly property real r: sigil.d * 0.34
            readonly property real c: sigil.d / 2
            function tri(start) {
                const p = [];
                for (let i = 0; i <= 3; i++) {
                    const a = (start + i * 120) * Math.PI / 180;
                    p.push(Qt.point(c + Math.cos(a) * r, c + Math.sin(a) * r));
                }
                return p;
            }
            ShapePath {
                fillColor: "transparent"
                strokeColor: root.alpha(root.cyan, 0.8)
                strokeWidth: 1.2
                PathPolyline { path: hex.tri(-90) }
            }
            ShapePath {
                fillColor: "transparent"
                strokeColor: root.alpha(root.cyan, 0.8)
                strokeWidth: 1.2
                PathPolyline { path: hex.tri(90) }
            }
        }
        Repeater {
            model: 12
            Text {
                required property int index
                readonly property real a: (index / 12) * Math.PI * 2 - Math.PI / 2
                x: sigil.d / 2 + Math.cos(a) * (sigil.d / 2 + 26) - width / 2
                y: sigil.d / 2 + Math.sin(a) * (sigil.d / 2 + 26) - height / 2
                rotation: index / 12 * 360
                text: "ΔΘΛΣΩΦΨΞΠΓΒΖ".charAt(index)
                color: root.gold
                opacity: root.ramp(root.progress, 0.6 + index / 12 * 0.3, 0.65 + index / 12 * 0.3)
                font.family: root.serif
                font.pixelSize: 22
            }
        }
        // The heart: a cyan diamond that brightens as the gate completes.
        Rectangle {
            anchors.centerIn: parent
            width: sigil.d * 0.12
            height: width
            rotation: 45 - sigil.rotation
            color: root.alpha(root.cyan, 0.15 + 0.75 * root.progress)
            border.width: 1.5
            border.color: root.gold
        }
    }

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: sigil.y + sigil.height + 70
        spacing: 8
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "The World"
            color: root.gold
            font.family: root.serif
            font.capitalization: Font.SmallCaps
            font.letterSpacing: 8
            font.pixelSize: 34
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: (root.lines[Math.max(0, Math.min(root.lines.length - 1, root.stage))] || "") + "…"
            visible: root.stage > 0
            color: root.inkDim
            font.family: root.serif
            font.italic: true
            font.pixelSize: 16
        }
        // Thin progress rule.
        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 320
            height: 10
            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 1; color: root.alpha(root.gold, 0.25) }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width * root.progress
                height: 1
                color: root.cyan
            }
            Rectangle {
                x: parent.width * root.progress - width / 2
                anchors.verticalCenter: parent.verticalCenter
                width: 7
                height: 7
                rotation: 45
                color: root.gold
            }
        }
    }
}
