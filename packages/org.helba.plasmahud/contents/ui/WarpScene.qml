import QtQuick
import QtQuick.Shapes
import QtQuick.Particles

// One screen of a gate warp. t runs 0..1 (gate out) then 1..2 (gate in).
// Every screen dims and whites out together; only the stage screen (the middle of
// the span) plays the gate itself:
//   out  the Chaos Gate sigil draws itself in, the area's keywords type into their
//        slots one by one, then gold floor rings rise around a column of light while
//        data streams upward; a white-out hides the switch
//   in   the light thins, the rings sink back to the floor, and the area is announced:
//        glyph, name, gold rules drawing outward
Item {
    id: sc

    required property QtObject hud
    property real t: 0
    property bool stage: true
    property string glyph: ""
    property string title: ""

    readonly property real out: Math.min(1, t)
    readonly property real back: Math.max(0, t - 1)
    function ramp(x, a, b) { return Math.max(0, Math.min(1, (x - a) / (b - a))); }
    // Rings, light and data swell in the second half of the gate out.
    readonly property real surge: t < 1 ? ramp(out, 0.45, 1) : 1 - ramp(back, 0, 0.7)
    readonly property real cx: width / 2
    readonly property real cy: height * 0.42
    readonly property real floorY: height * 0.78
    readonly property bool emitting: stage && t > 0.4 && t < 1.05

    // Keywords: "Whispering Iron Shrine" -> ["Whispering", "Iron", "Shrine"], keeping
    // two-word places ("Holy Ground") together as the third keyword.
    readonly property var words: {
        const w = String(title).split(" ").filter(x => x.length);
        return w.length <= 3 ? w : [w[0], w[1], w.slice(2).join(" ")];
    }

    // Veil (every screen).
    Rectangle {
        anchors.fill: parent
        color: sc.hud.glassBottom
        opacity: 0.88 * (sc.t < 1 ? sc.ramp(sc.out, 0, 0.3) : 1 - sc.ramp(sc.back, 0.78, 1))
    }

    // ------------------------------------------------------------ the gate (stage only)

    Item {
        anchors.fill: parent
        visible: sc.stage

        // Light column.
        Rectangle {
            x: sc.cx - width / 2
            width: 4 + 320 * sc.surge * sc.surge
            height: parent.height
            opacity: sc.surge
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.3; color: sc.hud.alpha(sc.hud.cyan, 0.35) }
                GradientStop { position: 0.5; color: sc.hud.light ? Qt.rgba(1, 0.98, 0.92, 0.9) : Qt.rgba(0.82, 0.96, 1, 0.75) }
                GradientStop { position: 0.7; color: sc.hud.alpha(sc.hud.cyan, 0.35) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        // Floor rings: flattened like The World's gate rings, dashed and turning.
        Repeater {
            model: 4
            Shape {
                id: ring
                required property int index
                readonly property real rx: 110 + index * 60 + sc.surge * (340 + index * 150)
                readonly property real ry: rx * 0.2
                readonly property real y0: sc.floorY - sc.surge * (60 + index * 170)
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                opacity: Math.min(1, sc.surge * 1.8) * (1 - index * 0.18)
                ShapePath {
                    fillColor: "transparent"
                    strokeColor: sc.hud.gold
                    strokeWidth: 2
                    strokeStyle: ShapePath.DashLine
                    dashPattern: ring.index % 2 ? [12, 5] : [28, 6]
                    dashOffset: sc.t * (ring.index % 2 ? -90 : 110)
                    PathAngleArc {
                        centerX: sc.cx; centerY: ring.y0
                        radiusX: ring.rx; radiusY: ring.ry
                        startAngle: 0; sweepAngle: 360
                    }
                }
                ShapePath {
                    fillColor: "transparent"
                    strokeColor: sc.hud.alpha(sc.hud.cyan, 0.55)
                    strokeWidth: 1
                    PathAngleArc {
                        centerX: sc.cx; centerY: ring.y0
                        radiusX: ring.rx * 0.9; radiusY: ring.ry * 0.9
                        startAngle: 0; sweepAngle: 360
                    }
                }
            }
        }

        // The sigil: draws itself in, turns, and gives way to the light.
        Item {
            id: sigil
            readonly property real d: Math.min(sc.width, sc.height) * 0.36
            readonly property real draw: sc.t < 1 ? sc.ramp(sc.out, 0.02, 0.45) : 1
            x: sc.cx - d / 2
            y: sc.cy - d / 2
            width: d
            height: d
            opacity: sc.t < 1 ? 1 - sc.ramp(sc.out, 0.8, 1) * 0.6 : 1 - sc.ramp(sc.back, 0, 0.35)
            rotation: sc.t * 70

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                // Outer circle, drawn clockwise.
                ShapePath {
                    fillColor: "transparent"
                    strokeColor: sc.hud.gold
                    strokeWidth: 2
                    capStyle: ShapePath.FlatCap
                    PathAngleArc {
                        centerX: sigil.d / 2; centerY: sigil.d / 2
                        radiusX: sigil.d / 2 - 2; radiusY: sigil.d / 2 - 2
                        startAngle: -90; sweepAngle: 360 * sigil.draw
                    }
                }
                // Inner circle, drawn the other way.
                ShapePath {
                    fillColor: "transparent"
                    strokeColor: sc.hud.alpha(sc.hud.gold, 0.6)
                    strokeWidth: 1
                    capStyle: ShapePath.FlatCap
                    PathAngleArc {
                        centerX: sigil.d / 2; centerY: sigil.d / 2
                        radiusX: sigil.d * 0.36; radiusY: sigil.d * 0.36
                        startAngle: 90; sweepAngle: -360 * sigil.draw
                    }
                }
            }
            // Hexagram, counter-turning.
            Shape {
                id: hex
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                rotation: -sc.t * 160
                opacity: sc.ramp(sigil.draw, 0.4, 1)
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
                    strokeColor: sc.hud.alpha(sc.hud.cyan, 0.8)
                    strokeWidth: 1.2
                    PathPolyline { path: hex.tri(-90) }
                }
                ShapePath {
                    fillColor: "transparent"
                    strokeColor: sc.hud.alpha(sc.hud.cyan, 0.8)
                    strokeWidth: 1.2
                    PathPolyline { path: hex.tri(90) }
                }
            }
            // Server glyphs lighting up around the rim.
            Repeater {
                model: 12
                Text {
                    required property int index
                    readonly property real a: (index / 12) * Math.PI * 2 - Math.PI / 2
                    x: sigil.d / 2 + Math.cos(a) * (sigil.d / 2 + 22) - width / 2
                    y: sigil.d / 2 + Math.sin(a) * (sigil.d / 2 + 22) - height / 2
                    rotation: index / 12 * 360
                    text: "ΔΘΛΣΩΦΨΞΠΓΒΖ".charAt(index)
                    color: sc.hud.gold
                    opacity: sc.ramp(sigil.draw, index / 12 * 0.8, index / 12 * 0.8 + 0.2)
                    font.family: sc.hud.serifFont
                    font.pixelSize: 18
                }
            }
            // Server glyph of the destination, at the heart.
            Text {
                anchors.centerIn: parent
                text: sc.glyph
                rotation: -sigil.rotation
                color: sc.hud.gold
                opacity: sc.ramp(sigil.draw, 0.5, 1)
                font.family: sc.hud.serifFont
                font.pixelSize: sigil.d * 0.22
            }
        }

        // Keyword slots: the area's three words typed in one by one.
        Row {
            id: slots
            anchors.horizontalCenter: parent.horizontalCenter
            y: sc.cy + sigil.d / 2 + 54
            spacing: 14
            opacity: sc.t < 1 ? 1 : 1 - sc.ramp(sc.back, 0, 0.3)
            Repeater {
                model: sc.words
                Item {
                    id: slot
                    required property int index
                    required property string modelData
                    readonly property real shown: sc.ramp(sc.out, 0.2 + index * 0.13, 0.3 + index * 0.13)
                    readonly property int letters: Math.round(modelData.length * shown)
                    width: Math.max(120, label.implicitWidth + 36)
                    height: 46
                    HackFrame {
                        anchors.fill: parent
                        hud: sc.hud
                        radius: 4
                        stud: 5
                        trim: 0.5 + slot.shown * 0.5
                    }
                    // A flash as each keyword locks in.
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 2
                        radius: 3
                        color: sc.hud.cyan
                        opacity: slot.shown > 0 && slot.shown < 1 ? 0.25 : slot.shown >= 1 ? 0.06 : 0
                    }
                    Text {
                        id: label
                        anchors.centerIn: parent
                        text: slot.modelData.substring(0, slot.letters)
                        color: sc.hud.ink
                        font.family: sc.hud.serifFont
                        font.capitalization: Font.SmallCaps
                        font.letterSpacing: 2
                        font.pixelSize: 20
                    }
                }
            }
        }

        // Data rising.
        ParticleSystem {
            id: ps
            running: sc.visible && sc.stage
        }
        ImageParticle {
            system: ps
            groups: ["streak"]
            source: Qt.resolvedUrl("../images/streak.png")
            color: sc.hud.cyan
            colorVariation: 0.12
            alpha: 0.9
            entryEffect: ImageParticle.Fade
        }
        ImageParticle {
            system: ps
            groups: ["mote"]
            source: Qt.resolvedUrl("../images/mote.png")
            color: "#ffffff"
            colorVariation: 0.25
            alpha: 0.8
            entryEffect: ImageParticle.Scale
        }
        ItemParticle {
            system: ps
            groups: ["glyph"]
            fade: true
            delegate: Text {
                text: "ΔΘΛΣΩΦΨΞΠΓ".charAt(Math.floor(Math.random() * 10))
                color: sc.hud.gold
                opacity: 0.85
                font.family: sc.hud.serifFont
                font.pixelSize: 16 + Math.floor(Math.random() * 16)
            }
        }
        Emitter {
            system: ps
            group: "streak"
            x: sc.cx - width / 2
            y: sc.floorY - 20
            width: 140 + 700 * sc.surge
            height: 40
            emitRate: sc.emitting ? 260 : 0
            lifeSpan: 1100
            lifeSpanVariation: 300
            size: 26
            sizeVariation: 12
            velocity: PointDirection { y: -950; yVariation: 380 }
        }
        Emitter {
            system: ps
            group: "mote"
            x: sc.cx - width / 2
            y: sc.floorY - 60
            width: 200 + 900 * sc.surge
            height: 120
            emitRate: sc.emitting ? 150 : 0
            lifeSpan: 1300
            lifeSpanVariation: 400
            size: 10
            sizeVariation: 8
            endSize: 2
            velocity: PointDirection { y: -420; yVariation: 220; xVariation: 60 }
        }
        Emitter {
            system: ps
            group: "glyph"
            x: sc.cx - width / 2
            y: sc.floorY - 40
            width: 520
            height: 60
            emitRate: sc.emitting ? 18 : 0
            lifeSpan: 1500
            velocity: PointDirection { y: -240; yVariation: 80; xVariation: 30 }
        }
    }

    // The peak (every screen) covers the switch. Dark: a midnight data-out with the
    // gate's light as a cyan bloom on the stage, never a white flash. Light: parchment.
    readonly property real peak: sc.t < 1 ? sc.ramp(sc.out, 0.8, 1) : 1 - Math.sqrt(sc.ramp(sc.back, 0.02, 0.35))
    Rectangle {
        anchors.fill: parent
        color: sc.hud.light ? "#f6f0e0" : "#050a18"
        opacity: 0.96 * sc.peak
    }
    Shape {
        id: bloom
        anchors.fill: parent
        visible: sc.stage
        opacity: sc.peak
        preferredRendererType: Shape.CurveRenderer
        readonly property real r: Math.max(sc.width, sc.height) * 0.42
        ShapePath {
            strokeColor: "transparent"
            fillGradient: RadialGradient {
                centerX: sc.cx; centerY: sc.cy
                focalX: sc.cx; focalY: sc.cy
                centerRadius: bloom.r
                focalRadius: 0
                GradientStop { position: 0.0; color: sc.hud.alpha(sc.hud.cyan, sc.hud.light ? 0.35 : 0.5) }
                GradientStop { position: 0.35; color: sc.hud.alpha(sc.hud.cyan, sc.hud.light ? 0.12 : 0.16) }
                GradientStop { position: 1.0; color: "transparent" }
            }
            PathRectangle { x: 0; y: 0; width: sc.width; height: sc.height }
        }
    }

    // Arrival (stage): the area's name, on a dark band so it reads over any wallpaper.
    Rectangle {
        visible: sc.stage && sc.title !== ""
        anchors.centerIn: arrival
        width: Math.min(sc.width, arrival.width + 520)
        height: arrival.height + 48
        opacity: arrival.opacity
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.25; color: sc.hud.alpha(sc.hud.glassBottom, 0.78) }
            GradientStop { position: 0.75; color: sc.hud.alpha(sc.hud.glassBottom, 0.78) }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }
    Column {
        id: arrival
        visible: sc.stage && sc.title !== ""
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -parent.height * 0.08
        spacing: 6
        opacity: sc.ramp(sc.back, 0.12, 0.28) * (1 - sc.ramp(sc.back, 0.78, 1))
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: sc.glyph !== ""
            text: sc.glyph
            color: sc.hud.gold
            font.family: sc.hud.serifFont
            font.pixelSize: 64
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 18
            readonly property real reach: sc.ramp(sc.back, 0.15, 0.5) * 180
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.reach
                height: 1
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: sc.hud.gold }
                }
            }
            Text {
                text: sc.title
                color: sc.hud.ink
                style: Text.Raised
                styleColor: sc.hud.alpha(sc.hud.glassBottom, 0.9)
                font.family: sc.hud.serifFont
                font.capitalization: Font.SmallCaps
                font.letterSpacing: 8
                font.pixelSize: 36
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.reach
                height: 1
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: sc.hud.gold }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }
        }
    }
}
