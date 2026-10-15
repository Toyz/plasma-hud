import QtQuick
import QtQuick.Shapes
import QtQuick.Effects

// 270-degree arc gauge with tick ring, rotating outer dash ring and a peak marker.
Item {
    id: g

    required property QtObject hud
    property string label: ""
    property real value: 0          // 0..100
    property real peak: 0           // 0..100, recent maximum
    property real reveal: 1         // 0..1, drives the boot sweep
    property string valueText: Math.round(value).toString()
    property string unit: "%"
    property string sub1: ""
    property string sub2: ""
    property color color: hud.level(value)
    property bool spinning: true

    implicitWidth: 150
    implicitHeight: 150

    readonly property real r: Math.min(width, height) / 2
    readonly property real cx: width / 2
    readonly property real cy: height / 2
    readonly property real arcR: r - 14
    property real shown: value * reveal
    Behavior on shown { NumberAnimation { duration: 650; easing.type: Easing.OutCubic } }
    Behavior on color { ColorAnimation { duration: 400 } }

    // Outer dashed ring, slowly rotating.
    Shape {
        id: outer
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        opacity: 0.55 * g.reveal
        ShapePath {
            fillColor: "transparent"
            strokeColor: g.hud.alpha(g.hud.accent, 0.5)
            strokeWidth: 1
            strokeStyle: ShapePath.DashLine
            dashPattern: [2, 5]
            PathAngleArc {
                centerX: g.cx; centerY: g.cy
                radiusX: g.r - 1.5; radiusY: g.r - 1.5
                startAngle: 0; sweepAngle: 360
            }
        }
        ShapePath {
            fillColor: "transparent"
            strokeColor: g.hud.accent2
            strokeWidth: 2
            capStyle: ShapePath.FlatCap
            PathAngleArc {
                centerX: g.cx; centerY: g.cy
                radiusX: g.r - 1.5; radiusY: g.r - 1.5
                startAngle: 200; sweepAngle: 24
            }
        }
        RotationAnimation on rotation {
            running: g.spinning && g.visible
            from: 0; to: 360
            duration: 24000
            loops: Animation.Infinite
        }
    }

    // Tick ring.
    Canvas {
        id: ticks
        anchors.fill: parent
        opacity: g.reveal
        renderTarget: Canvas.FramebufferObject
        property color tickColor: g.hud.accent
        onTickColorChanged: requestPaint()
        onWidthChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const n = 54, rr = g.arcR + 8;
            for (let i = 0; i <= n; i++) {
                const a = (135 + 270 * i / n) * Math.PI / 180;
                const major = i % 9 === 0;
                const len = major ? 5 : 2.5;
                ctx.strokeStyle = g.hud.css(tickColor, major ? 0.7 : 0.25);
                ctx.lineWidth = major ? 1.5 : 1;
                ctx.beginPath();
                ctx.moveTo(g.cx + Math.cos(a) * rr, g.cy + Math.sin(a) * rr);
                ctx.lineTo(g.cx + Math.cos(a) * (rr + len), g.cy + Math.sin(a) * (rr + len));
                ctx.stroke();
            }
        }
    }

    // Track and value arc.
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: "transparent"
            strokeColor: g.hud.alpha(g.color, 0.12)
            strokeWidth: 7
            capStyle: ShapePath.FlatCap
            PathAngleArc {
                centerX: g.cx; centerY: g.cy
                radiusX: g.arcR; radiusY: g.arcR
                startAngle: 135; sweepAngle: 270
            }
        }
    }
    Shape {
        id: valueArc
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        layer.enabled: g.hud.glow > 0
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: g.color
            shadowBlur: 0.6
            shadowOpacity: g.hud.glow
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
            blurMax: 20
        }
        ShapePath {
            fillColor: "transparent"
            strokeColor: g.color
            strokeWidth: 7
            capStyle: ShapePath.FlatCap
            PathAngleArc {
                centerX: g.cx; centerY: g.cy
                radiusX: g.arcR; radiusY: g.arcR
                startAngle: 135; sweepAngle: Math.max(0.01, 270 * Math.min(100, g.shown) / 100)
            }
        }
    }
    // Segment gaps cut across the arc so it reads as a meter, not a line.
    Canvas {
        anchors.fill: parent
        renderTarget: Canvas.FramebufferObject
        onWidthChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            ctx.strokeStyle = "rgba(5,7,12,1)";
            ctx.lineWidth = 1.5;
            for (let i = 1; i < 30; i++) {
                const a = (135 + 270 * i / 30) * Math.PI / 180;
                ctx.beginPath();
                ctx.moveTo(g.cx + Math.cos(a) * (g.arcR - 5), g.cy + Math.sin(a) * (g.arcR - 5));
                ctx.lineTo(g.cx + Math.cos(a) * (g.arcR + 5), g.cy + Math.sin(a) * (g.arcR + 5));
                ctx.stroke();
            }
        }
    }

    // Peak marker.
    Item {
        anchors.fill: parent
        rotation: -135 + 270 * Math.min(100, g.peak) / 100
        visible: g.peak > 0.5 && g.reveal > 0.9
        Behavior on rotation { NumberAnimation { duration: 400 } }
        Rectangle {
            x: g.cx - 1
            y: g.cy - g.arcR - 9
            width: 2
            height: 7
            color: g.hud.accent2
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: 0
        opacity: g.reveal

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: g.label
            color: g.hud.gold
            font.family: g.hud.serifFont
            font.capitalization: Font.SmallCaps
            font.pixelSize: 12
            font.letterSpacing: 2
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 1
            Text {
                text: g.valueText
                color: g.hud.text
                font.family: g.hud.serifFont
                font.pixelSize: Math.round(g.r * 0.44)
                font.weight: Font.Medium
                layer.enabled: g.hud.glow > 0
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: g.color
                    shadowBlur: 0.5
                    shadowOpacity: g.hud.glow * 0.9
                    shadowHorizontalOffset: 0
                    shadowVerticalOffset: 0
                }
            }
            Text {
                anchors.baseline: parent.children[0].baseline
                text: g.unit
                color: g.color
                font.family: g.hud.monoFont
                font.pixelSize: Math.round(g.r * 0.17)
                font.weight: Font.Bold
            }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: g.sub1
            color: g.hud.text
            opacity: 0.8
            font.family: g.hud.monoFont
            font.pixelSize: 10
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: g.sub2
            color: g.hud.dim
            font.family: g.hud.monoFont
            font.pixelSize: 10
        }
    }
}
