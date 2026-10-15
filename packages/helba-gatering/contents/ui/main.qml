import QtQuick
import QtQuick.Shapes
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.kwin as KWin

// Meta+Tab: the gate ring. Live windows stand on a tilted ring around the Chaos Gate
// sigil; the one you are on swings to the front, largest, with its title and area
// under it. Turns the short way round. Self-contained (it runs inside KWin) with its
// own copy of the Helba World palette, light or dark from the KDE color scheme.
KWin.TabBoxSwitcher {
    id: tabBox

    readonly property bool light: Kirigami.Theme.backgroundColor.hslLightness > 0.5
    readonly property color gold: light ? "#8a6418" : "#b8935a"
    readonly property color cyan: light ? "#14708a" : "#8fe3ff"
    readonly property color ink: light ? "#1a2033" : "#eaf0fb"
    readonly property color inkDim: light ? "#5a6380" : "#8d98b6"
    readonly property color veil: light ? Qt.rgba(0.95, 0.93, 0.87, 0.82) : Qt.rgba(0.02, 0.035, 0.09, 0.82)
    readonly property color well: light ? "#e9e2cf" : "#070b1a"
    readonly property string serif: "Noto Serif"
    function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a); }

    currentIndex: (instantiator.object as RingDialog)?.currentIndex ?? currentIndex

    Instantiator {
        id: instantiator
        active: tabBox.visible
        delegate: RingDialog {}
    }

    component RingDialog: PlasmaCore.Dialog {
        property alias currentIndex: ring.current
        location: PlasmaCore.Types.Floating
        visible: tabBox.visible
        flags: Qt.Popup | Qt.X11BypassWindowManagerHint
        backgroundHints: PlasmaCore.Dialog.NoBackground
        x: tabBox.screenGeometry.x
        y: tabBox.screenGeometry.y

        mainItem: Item {
            id: stage
            width: tabBox.screenGeometry.width
            height: tabBox.screenGeometry.height
            focus: true

            readonly property real cx: width / 2
            readonly property real cy: height * 0.46

            Rectangle {
                anchors.fill: parent
                color: tabBox.veil
            }

            // The sigil, turning slowly behind the ring.
            Item {
                id: sigil
                readonly property real d: Math.min(stage.width, stage.height) * 0.46
                x: stage.cx - d / 2
                y: stage.cy - d / 2
                width: d
                height: d
                opacity: 0.55
                RotationAnimation on rotation { from: 0; to: 360; duration: 90000; loops: Animation.Infinite; running: tabBox.visible }
                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        fillColor: "transparent"
                        strokeColor: tabBox.gold
                        strokeWidth: 1.5
                        strokeStyle: ShapePath.DashLine
                        dashPattern: [16, 6]
                        PathAngleArc { centerX: sigil.d / 2; centerY: sigil.d / 2; radiusX: sigil.d / 2 - 2; radiusY: sigil.d / 2 - 2; sweepAngle: 360 }
                    }
                    ShapePath {
                        fillColor: "transparent"
                        strokeColor: tabBox.alpha(tabBox.cyan, 0.5)
                        strokeWidth: 1
                        PathAngleArc { centerX: sigil.d / 2; centerY: sigil.d / 2; radiusX: sigil.d * 0.36; radiusY: sigil.d * 0.36; sweepAngle: 360 }
                    }
                }
                Repeater {
                    model: 12
                    Text {
                        required property int index
                        readonly property real a: index / 12 * Math.PI * 2
                        x: sigil.d / 2 + Math.cos(a) * (sigil.d / 2 + 20) - width / 2
                        y: sigil.d / 2 + Math.sin(a) * (sigil.d / 2 + 20) - height / 2
                        rotation: index / 12 * 360 + 90
                        text: "ΔΘΛΣΩΦΨΞΠΓΒΖ".charAt(index)
                        color: tabBox.gold
                        font.family: tabBox.serif
                        font.pixelSize: 18
                    }
                }
            }

            // The ring of windows. `turn` eases toward the current index the short way.
            Item {
                id: ring
                anchors.fill: parent
                property int current: tabBox.currentIndex
                property real turn: current
                readonly property int n: Math.max(1, cards.count)
                readonly property real rx: Math.min(stage.width * 0.36, 820)
                readonly property real ry: stage.height * 0.17
                readonly property real cardW: Math.min(stage.width * 0.22, 440) * (n > 10 ? 0.8 : 1)
                readonly property real cardH: cardW * 0.62

                onCurrentChanged: {
                    let d = current - (turn % n + n) % n;
                    if (d > n / 2) d -= n;
                    if (d < -n / 2) d += n;
                    spin.to = turn + d;
                    spin.restart();
                }
                NumberAnimation { id: spin; target: ring; property: "turn"; duration: 260; easing.type: Easing.OutCubic }

                Repeater {
                    id: cards
                    model: tabBox.model
                    Item {
                        id: card
                        required property int index
                        required property var model
                        readonly property real a: (index - ring.turn) / ring.n * Math.PI * 2
                        readonly property real depth: (Math.cos(a) + 1) / 2          // 1 front, 0 back
                        readonly property bool front: index === ring.current
                        width: ring.cardW
                        height: ring.cardH
                        x: stage.cx + Math.sin(a) * ring.rx - width / 2
                        y: stage.cy + Math.cos(a) * ring.ry - height / 2
                        z: depth * 100
                        scale: 0.5 + 0.5 * depth
                        opacity: 0.35 + 0.65 * depth

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: -6
                            color: tabBox.well
                            border.width: card.front ? 1.5 : 1
                            border.color: tabBox.alpha(card.front ? tabBox.gold : tabBox.cyan, card.front ? 1 : 0.4)
                        }
                        KWin.WindowThumbnail {
                            anchors.fill: parent
                            wId: card.model.windowId
                        }
                        Repeater {
                            model: card.front ? 4 : 0
                            Rectangle {
                                required property int index
                                width: 9
                                height: 9
                                rotation: 45
                                color: tabBox.gold
                                x: (index % 2 ? card.width + 6 : -6) - width / 2
                                y: (index < 2 ? -6 : card.height + 6) - height / 2
                            }
                        }
                        // Icon tab under each card.
                        Kirigami.Icon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.bottom
                            anchors.topMargin: 10
                            width: 28
                            height: 28
                            source: card.model.icon
                        }
                        TapHandler {
                            onSingleTapped: {
                                if (card.front) tabBox.model.activate(card.index);
                                else ring.current = card.index;
                            }
                        }
                    }
                }
            }

            // The one you are on: title, area, and a gold rule either side.
            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                y: stage.cy + ring.ry + ring.cardH / 2 + 64
                spacing: 4
                readonly property var cur: cards.count ? cards.itemAt(ring.current) : null
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 16
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 120
                        height: 1
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: "transparent" }
                            GradientStop { position: 1; color: tabBox.gold }
                        }
                    }
                    Text {
                        width: Math.min(implicitWidth, stage.width * 0.5)
                        text: parent.parent.cur ? parent.parent.cur.model.caption : "No windows"
                        elide: Text.ElideMiddle
                        color: tabBox.ink
                        font.family: tabBox.serif
                        font.pixelSize: 22
                    }
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 120
                        height: 1
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: tabBox.gold }
                            GradientStop { position: 1; color: "transparent" }
                        }
                    }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: parent.cur ? ((parent.cur.model.minimized ? "resting  ·  " : "") + (parent.cur.model.desktopName || "")) : ""
                    color: tabBox.gold
                    font.family: tabBox.serif
                    font.italic: true
                    font.pixelSize: 13
                }
            }

            Connections {
                target: tabBox
                function onCurrentIndexChanged() { ring.current = tabBox.currentIndex; }
            }
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Left) ring.current = (ring.current + ring.n - 1) % ring.n;
                else if (event.key === Qt.Key_Right) ring.current = (ring.current + 1) % ring.n;
            }
        }

        onSceneGraphError: () => {
            // Intentionally empty: QtQuick may otherwise qFatal on a graphics reset.
        }
    }
}
