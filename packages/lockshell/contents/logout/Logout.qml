import QtQuick
import QtQuick.Shapes
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.coreaddons as KCoreAddons
import org.kde.plasma.private.sessions

// Helba World logout screen (.hack, The World). A midnight veil with the turning Chaos
// Gate sigil, your avatar in a gold diamond, and the ways out as gold-trimmed plates:
// sleep, hibernate, restart, shut down, log out, lock, stay. Asked for one specific
// action (from a menu), it shows just that plate with a countdown ring, like stock.
// Arrows move, Enter chooses, Esc stays.
//
// ksmserver-logout-greeter provides sdtype, maysd, canLogout, spdMethods,
// softwareUpdatePending and the reboot-to-firmware / boot loader hints.
Item {
    id: root

    signal logoutRequested()
    signal haltRequested()
    signal haltUpdateRequested()
    signal suspendRequested(int spdMethod)
    signal rebootRequested()
    signal rebootRequested2(int opt)
    signal rebootUpdateRequested()
    signal cancelRequested()
    signal lockScreenRequested()
    signal cancelSoftwareUpdateRequested()

    // ------------------------------------------------------------ palette

    readonly property bool light: Kirigami.Theme.backgroundColor.hslLightness > 0.5
    readonly property color gold: light ? "#8a6418" : "#b8935a"
    readonly property color cyan: light ? "#14708a" : "#8fe3ff"
    readonly property color ink: light ? "#1a2033" : "#eaf0fb"
    readonly property color inkDim: light ? "#5a6380" : "#8d98b6"
    readonly property color crit: light ? "#c81e45" : "#ff3864"
    readonly property color glass: light ? Qt.rgba(0.95, 0.93, 0.87, 1) : Qt.rgba(0.02, 0.035, 0.09, 1)
    readonly property color glassTop: light ? Qt.rgba(0.985, 0.97, 0.925, 1) : Qt.rgba(0.09, 0.12, 0.26, 1)
    readonly property string serif: "Noto Serif"
    function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a); }

    // ------------------------------------------------------------ what to offer

    readonly property bool showAll: sdtype === ShutdownType.ShutdownTypeDefault
    readonly property var actions: {
        const a = [];
        if (spdMethods.SuspendState && showAll) a.push({ key: "sleep", glyph: "◇", label: "Sleep", note: "rest, keep everything open" });
        if (spdMethods.HibernateState && showAll) a.push({ key: "hibernate", glyph: "◈", label: "Hibernate", note: "to disk, power off" });
        if (maysd && (sdtype === ShutdownType.ShutdownTypeReboot || showAll))
            a.push({ key: "reboot", glyph: "↻", label: softwareUpdatePending ? "Update and restart" : "Restart", note: "come back to The World" });
        if (maysd && (sdtype === ShutdownType.ShutdownTypeHalt || showAll))
            a.push({ key: "halt", glyph: "Ω", label: softwareUpdatePending ? "Update and shut down" : "Shut down", note: "close the gate", danger: true });
        if (canLogout && (sdtype === ShutdownType.ShutdownTypeNone || showAll)) a.push({ key: "logout", glyph: "Γ", label: "Log out", note: "end this session" });
        if (showAll) a.push({ key: "lock", glyph: "Ξ", label: "Lock", note: "step away" });
        a.push({ key: "cancel", glyph: "←", label: "Stay", note: "back to the field" });
        return a;
    }
    property int current: 0
    Component.onCompleted: {
        // Start on what was asked for (or on Stay when everything is offered).
        current = showAll ? actions.length - 1 : 0;
        plates.forceActiveFocus();
    }

    function run(key) {
        switch (key) {
        case "sleep": root.suspendRequested(2); break;
        case "hibernate": root.suspendRequested(4); break;
        case "reboot": softwareUpdatePending ? root.rebootUpdateRequested() : root.rebootRequested(); break;
        case "halt": softwareUpdatePending ? root.haltUpdateRequested() : root.haltRequested(); break;
        case "logout": root.logoutRequested(); break;
        case "lock": root.lockScreenRequested(); break;
        default: root.cancelRequested();
        }
    }

    // A specific request (Restart, Shut down, Log out from a menu) goes ahead after 30 s.
    property real remaining: 30
    Timer {
        running: !root.showAll
        interval: 1000
        repeat: true
        onTriggered: {
            root.remaining--;
            if (root.remaining <= 0) root.run(root.actions[0].key);
        }
    }

    QQC2.Action {
        shortcut: "Escape"
        onTriggered: root.cancelRequested()
    }

    // ------------------------------------------------------------ veil + sigil

    Rectangle {
        anchors.fill: parent
        color: root.glass
        opacity: 0.86
    }
    MouseArea {
        anchors.fill: parent
        onClicked: root.cancelRequested()
    }

    Item {
        id: sigil
        readonly property real d: Math.min(root.width, root.height) * 0.7
        x: (root.width - d) / 2
        y: (root.height - d) / 2
        width: d
        height: d
        opacity: 0.32
        RotationAnimation on rotation { from: 0; to: 360; duration: 180000; loops: Animation.Infinite }
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: "transparent"
                strokeColor: root.gold
                strokeWidth: 1.5
                strokeStyle: ShapePath.DashLine
                dashPattern: [18, 7]
                PathAngleArc { centerX: sigil.d / 2; centerY: sigil.d / 2; radiusX: sigil.d / 2 - 2; radiusY: sigil.d / 2 - 2; sweepAngle: 360 }
            }
            ShapePath {
                fillColor: "transparent"
                strokeColor: root.alpha(root.cyan, 0.5)
                strokeWidth: 1
                PathAngleArc { centerX: sigil.d / 2; centerY: sigil.d / 2; radiusX: sigil.d * 0.4; radiusY: sigil.d * 0.4; sweepAngle: 360 }
            }
        }
        Repeater {
            model: 12
            Text {
                required property int index
                readonly property real a: index / 12 * Math.PI * 2
                x: sigil.d / 2 + Math.cos(a) * (sigil.d / 2 + 24) - width / 2
                y: sigil.d / 2 + Math.sin(a) * (sigil.d / 2 + 24) - height / 2
                rotation: index / 12 * 360 + 90
                text: "ΔΘΛΣΩΦΨΞΠΓΒΖ".charAt(index)
                color: root.gold
                font.family: root.serif
                font.pixelSize: 22
            }
        }
    }

    // ------------------------------------------------------------ who, and the question

    KCoreAddons.KUser { id: kuser }

    Column {
        id: head
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height * 0.5 - height - 40
        spacing: 12

        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 110
            height: 110
            Item {
                anchors.centerIn: parent
                width: 76
                height: 76
                rotation: 45
                clip: true
                Rectangle { anchors.fill: parent; color: root.alpha(root.cyan, 0.12) }
                Image {
                    anchors.centerIn: parent
                    width: 108
                    height: 108
                    rotation: -45
                    fillMode: Image.PreserveAspectCrop
                    smooth: true
                    source: kuser.faceIconUrl
                }
                Text {
                    anchors.centerIn: parent
                    rotation: -45
                    visible: String(kuser.faceIconUrl) === ""
                    text: String(kuser.loginName || "?").charAt(0).toUpperCase()
                    color: root.gold
                    font.family: root.serif
                    font.pixelSize: 34
                }
            }
            Rectangle {
                anchors.centerIn: parent
                width: 78
                height: 78
                rotation: 45
                color: "transparent"
                border.width: 1.5
                border.color: root.gold
            }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.showAll ? "Leave The World?" : root.actions[0].label + " in " + Math.max(0, Math.round(root.remaining)) + "s"
            color: root.gold
            font.family: root.serif
            font.capitalization: Font.SmallCaps
            font.letterSpacing: 4
            font.pixelSize: 30
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: kuser.fullName || kuser.loginName
            color: root.inkDim
            font.family: root.serif
            font.italic: true
            font.pixelSize: 15
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: rebootToFirmwareSetup || rebootToBootLoaderMenu || rebootToBootLoaderEntry !== ""
            text: rebootToFirmwareSetup ? "Restarting into the firmware setup."
                : rebootToBootLoaderMenu ? "Restarting into the boot loader menu."
                : "Restarting into " + rebootToBootLoaderEntry + "."
            color: root.cyan
            font.family: root.serif
            font.italic: true
            font.pixelSize: 13
        }
    }

    // ------------------------------------------------------------ the plates

    Row {
        id: plates
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height * 0.5 + 10
        spacing: 18
        focus: true
        Keys.onLeftPressed: root.current = (root.current + root.actions.length - 1) % root.actions.length
        Keys.onRightPressed: root.current = (root.current + 1) % root.actions.length
        Keys.onTabPressed: root.current = (root.current + 1) % root.actions.length
        Keys.onBacktabPressed: root.current = (root.current + root.actions.length - 1) % root.actions.length
        Keys.onReturnPressed: root.run(root.actions[root.current].key)
        Keys.onEnterPressed: root.run(root.actions[root.current].key)
        Keys.onSpacePressed: root.run(root.actions[root.current].key)

        Repeater {
            model: root.actions
            Item {
                id: plate
                required property var modelData
                required property int index
                readonly property bool on: index === root.current || ma.containsMouse
                readonly property color tone: modelData.danger && on ? root.crit : root.gold
                width: 132
                height: 150

                Rectangle {
                    anchors.fill: parent
                    radius: 5
                    gradient: Gradient {
                        GradientStop { position: 0; color: root.alpha(root.glassTop, plate.on ? 0.92 : 0.7) }
                        GradientStop { position: 1; color: root.alpha(root.glass, plate.on ? 0.95 : 0.75) }
                    }
                    border.width: plate.on ? 1.5 : 1
                    border.color: root.alpha(plate.tone, plate.on ? 1 : 0.5)
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 4
                        radius: 3
                        color: plate.on ? root.alpha(plate.modelData.danger ? root.crit : root.cyan, 0.1) : "transparent"
                        border.width: 1
                        border.color: root.alpha(plate.tone, 0.2)
                    }
                }
                Repeater {
                    model: plate.on ? 4 : 0
                    Rectangle {
                        required property int index
                        width: 8
                        height: 8
                        rotation: 45
                        color: plate.tone
                        x: (index % 2 ? plate.width : 0) - width / 2
                        y: (index < 2 ? 0 : plate.height) - height / 2
                    }
                }

                // The glyph in a diamond, with the countdown ring around it when one
                // action was asked for.
                Item {
                    id: emblem
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 22
                    width: 62
                    height: 62
                    Rectangle {
                        anchors.centerIn: parent
                        width: 40
                        height: 40
                        rotation: 45
                        color: root.alpha(root.glass, 0.6)
                        border.width: 1.2
                        border.color: root.alpha(plate.tone, 0.9)
                    }
                    Text {
                        anchors.centerIn: parent
                        text: plate.modelData.glyph
                        color: plate.on ? (plate.modelData.danger ? root.crit : root.cyan) : plate.tone
                        font.family: root.serif
                        font.pixelSize: 22
                    }
                    Shape {
                        anchors.fill: parent
                        visible: !root.showAll && plate.index === 0
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath {
                            fillColor: "transparent"
                            strokeColor: root.cyan
                            strokeWidth: 2
                            capStyle: ShapePath.RoundCap
                            PathAngleArc {
                                centerX: 31; centerY: 31; radiusX: 30; radiusY: 30
                                startAngle: -90; sweepAngle: 360 * root.remaining / 30
                            }
                        }
                    }
                }
                Column {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 96
                    spacing: 3
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: plate.modelData.label
                        color: root.ink
                        font.family: root.serif
                        font.capitalization: Font.SmallCaps
                        font.letterSpacing: 1.5
                        font.pixelSize: 15
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: plate.width - 16
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        text: plate.modelData.note
                        color: root.inkDim
                        font.family: root.serif
                        font.italic: true
                        font.pixelSize: 10
                    }
                }
                MouseArea {
                    id: ma
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.current = plate.index
                    onClicked: root.run(plate.modelData.key)
                }
            }
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: plates.y + plates.height + 26
        text: "←  →  choose      ⏎  go      Esc  stay"
        color: root.alpha(root.inkDim, 0.85)
        font.family: root.serif
        font.pixelSize: 12
    }
}
