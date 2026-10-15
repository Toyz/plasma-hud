import QtQuick
import QtQuick.Shapes

// Helba World login (.hack, The World), for SDDM's Qt 6 greeter. Every screen gets
// the background, a light veil and the Chaos Gate sigil; the primary screen also gets
// the clock and "The World" plate: user diamonds (left / right to switch), a glass
// password field, the session, and power keycaps. Shakes on a failed login.
//
// SDDM provides: sddm (login, power, hostName, loginFailed), userModel, sessionModel,
// keyboard, config (theme.conf) and primaryScreen.
Rectangle {
    id: root

    width: 1920
    height: 1080
    color: glass

    // ------------------------------------------------------------ palette

    readonly property bool light: String(config.light) === "1"
    readonly property color gold: light ? "#8a6418" : "#b8935a"
    readonly property color cyan: light ? "#14708a" : "#8fe3ff"
    readonly property color ink: light ? "#1a2033" : "#eaf0fb"
    readonly property color inkDim: light ? "#5a6380" : "#8d98b6"
    readonly property color crit: light ? "#c81e45" : "#ff3864"
    readonly property color glass: light ? Qt.rgba(0.95, 0.93, 0.87, 1) : Qt.rgba(0.02, 0.035, 0.09, 1)
    readonly property color glassTop: light ? Qt.rgba(0.985, 0.97, 0.925, 1) : Qt.rgba(0.09, 0.12, 0.26, 1)
    readonly property color well: light ? "#faf7ee" : "#060a18"
    readonly property string serif: "Noto Serif"
    function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a); }

    readonly property bool primary: typeof primaryScreen === "undefined" ? true : primaryScreen

    // ------------------------------------------------------------ users and sessions

    // The models only expose their roles to delegates, so mirror what we need.
    property var users: []
    property int user: Math.max(0, userModel.lastIndex)
    property var sessions: []
    property int session: Math.max(0, sessionModel.lastIndex)

    Repeater {
        model: userModel
        Item {
            required property int index
            required property string name
            required property string realName
            required property string icon
            Component.onCompleted: {
                const u = root.users.slice();
                u[index] = { name: name, realName: realName || name, icon: icon };
                root.users = u;
            }
        }
    }
    Repeater {
        model: sessionModel
        Item {
            required property int index
            required property string name
            Component.onCompleted: {
                const s = root.sessions.slice();
                s[index] = name;
                root.sessions = s;
            }
        }
    }
    readonly property var current: users[user] || { name: userModel.lastUser || "", realName: userModel.lastUser || "", icon: "" }

    function login() {
        if (!current.name) return;
        sddm.login(current.name, field.text, session);
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            field.text = "";
            note.text = "The gate did not open. Try again.";
            shake.restart();
            field.forceActiveFocus();
        }
    }

    // ------------------------------------------------------------ background

    Image {
        id: bg
        anchors.fill: parent
        source: config.background || ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        smooth: true
    }
    Rectangle {
        anchors.fill: parent
        color: root.glass
        opacity: bg.status === Image.Ready ? (root.primary ? 0.42 : 0.2) : 1
    }

    Item {
        id: sigil
        readonly property real d: Math.min(root.width, root.height) * 0.62
        x: (root.width - d) / 2
        y: (root.height - d) / 2
        width: d
        height: d
        opacity: 0.4
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

    // ------------------------------------------------------------ clock

    property date now: new Date()
    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.primary ? root.height * 0.07 : root.height * 0.38
        spacing: 0
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            Repeater {
                model: [Qt.formatTime(root.now, "HH"), ":", Qt.formatTime(root.now, "mm")]
                Text {
                    required property string modelData
                    required property int index
                    text: modelData
                    color: index === 1 ? root.gold : root.ink
                    opacity: index === 1 && root.now.getSeconds() % 2 ? 0.55 : 1
                    style: Text.Raised
                    styleColor: root.alpha(root.glass, 0.55)
                    font.family: root.serif
                    font.pixelSize: root.primary ? 72 : 132
                    font.weight: Font.Light
                }
            }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDate(root.now, "dddd, d MMMM yyyy")
            color: root.gold
            style: Text.Raised
            styleColor: root.alpha(root.glass, 0.6)
            font.family: root.serif
            font.italic: true
            font.pixelSize: root.primary ? 16 : 22
        }
    }

    // ------------------------------------------------------------ the plate

    Item {
        id: plate
        visible: root.primary
        width: Math.min(560, root.width - 64)
        height: col.implicitHeight + 64
        x: (root.width - width) / 2 + shakeX
        y: (root.height - height) / 2 + root.height * 0.03
        property real shakeX: 0

        SequentialAnimation {
            id: shake
            NumberAnimation { target: plate; property: "shakeX"; to: -14; duration: 50 }
            NumberAnimation { target: plate; property: "shakeX"; to: 12; duration: 70 }
            NumberAnimation { target: plate; property: "shakeX"; to: -8; duration: 60 }
            NumberAnimation { target: plate; property: "shakeX"; to: 4; duration: 50 }
            NumberAnimation { target: plate; property: "shakeX"; to: 0; duration: 50 }
        }

        Rectangle {
            anchors.fill: parent
            radius: 6
            gradient: Gradient {
                GradientStop { position: 0; color: root.alpha(root.glassTop, 0.74) }
                GradientStop { position: 1; color: root.alpha(root.glass, 0.82) }
            }
            border.width: 1
            border.color: root.alpha(root.gold, 0.85)
            Rectangle {
                anchors.fill: parent
                anchors.margins: 4
                radius: 4
                color: "transparent"
                border.width: 1
                border.color: root.alpha(root.gold, 0.2)
            }
        }
        Repeater {
            model: 4
            Rectangle {
                required property int index
                width: 10
                height: 10
                rotation: 45
                color: root.gold
                x: (index % 2 ? plate.width : 0) - width / 2
                y: (index < 2 ? 0 : plate.height) - height / 2
            }
        }

        Column {
            id: col
            x: 40
            y: 32
            width: plate.width - 80
            spacing: 14

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "The World"
                color: root.gold
                font.family: root.serif
                font.capitalization: Font.SmallCaps
                font.letterSpacing: 5
                font.pixelSize: 26
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Server  ·  " + (sddm.hostName || "")
                color: root.inkDim
                font.family: root.serif
                font.italic: true
                font.pixelSize: 12
            }

            // Users as diamonds; the chosen one is large and lit.
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 18
                Repeater {
                    model: root.users.length
                    Item {
                        id: who
                        required property int index
                        readonly property var u: root.users[index] || {}
                        readonly property bool on: index === root.user
                        width: on ? 104 : 54
                        height: 104
                        opacity: on ? 1 : 0.6
                        Behavior on width { NumberAnimation { duration: 200 } }
                        Item {
                            anchors.centerIn: parent
                            width: who.on ? 74 : 38
                            height: width
                            rotation: 45
                            clip: true
                            Rectangle { anchors.fill: parent; color: root.alpha(root.cyan, 0.12) }
                            Image {
                                anchors.centerIn: parent
                                width: parent.width * 1.42
                                height: width
                                rotation: -45
                                fillMode: Image.PreserveAspectCrop
                                smooth: true
                                source: who.u.icon || ""
                            }
                            Text {
                                anchors.centerIn: parent
                                rotation: -45
                                visible: !who.u.icon
                                text: String(who.u.name || "?").charAt(0).toUpperCase()
                                color: root.gold
                                font.family: root.serif
                                font.pixelSize: who.on ? 34 : 18
                            }
                        }
                        Rectangle {
                            anchors.centerIn: parent
                            width: (who.on ? 74 : 38) + 2
                            height: width
                            rotation: 45
                            color: "transparent"
                            border.width: who.on ? 1.5 : 1
                            border.color: root.alpha(root.gold, who.on ? 1 : 0.6)
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.user = who.index;
                                field.forceActiveFocus();
                            }
                        }
                    }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Welcome back, " + (root.current.realName || root.current.name || "traveller")
                color: root.ink
                font.family: root.serif
                font.italic: true
                font.pixelSize: 16
            }

            // Password.
            Item {
                width: parent.width
                height: 46
                Rectangle {
                    anchors.fill: parent
                    radius: 4
                    color: root.alpha(root.well, 0.72)
                    border.width: field.activeFocus ? 1.5 : 1
                    border.color: field.activeFocus ? root.gold : root.alpha(root.gold, 0.45)
                }
                Text {
                    id: prompt
                    x: 16
                    anchors.verticalCenter: parent.verticalCenter
                    text: "›"
                    color: root.gold
                    font.pixelSize: 20
                }
                TextInput {
                    id: field
                    anchors.left: prompt.right
                    anchors.leftMargin: 10
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    focus: true
                    echoMode: TextInput.Password
                    passwordCharacter: "◆"
                    passwordMaskDelay: 0
                    color: root.ink
                    selectionColor: root.alpha(root.cyan, 0.4)
                    font.family: root.serif
                    font.pixelSize: 17
                    font.letterSpacing: 3
                    clip: true
                    onAccepted: root.login()
                    onTextEdited: note.text = ""
                    Keys.onPressed: event => {
                        // Left / right switch users while the field is empty.
                        if (text.length) return;
                        if (event.key === Qt.Key_Left) {
                            root.user = (root.user + root.users.length - 1) % Math.max(1, root.users.length);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Right) {
                            root.user = (root.user + 1) % Math.max(1, root.users.length);
                            event.accepted = true;
                        }
                    }
                }
                Text {
                    anchors.left: field.left
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !field.text
                    text: "Enter your password"
                    color: root.inkDim
                    font.family: root.serif
                    font.italic: true
                    font.pixelSize: 14
                }
            }

            Text {
                id: note
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                visible: text.length > 0 || keyboard.capsLock
                text: ""
                color: root.crit
                font.family: root.serif
                font.italic: true
                font.pixelSize: 13
            }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                visible: keyboard.capsLock
                text: "Caps Lock is on"
                color: root.inkDim
                font.family: root.serif
                font.italic: true
                font.pixelSize: 13
            }

            // Session: click to cycle.
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 10
                visible: root.sessions.length > 0
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Session"
                    color: root.gold
                    font.family: root.serif
                    font.capitalization: Font.SmallCaps
                    font.letterSpacing: 1.5
                    font.pixelSize: 12
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "◂  " + (root.sessions[root.session] || "") + "  ▸"
                    color: sessMa.containsMouse ? root.cyan : root.ink
                    font.family: root.serif
                    font.pixelSize: 13
                    MouseArea {
                        id: sessMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.session = (root.session + 1) % Math.max(1, root.sessions.length)
                    }
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 18
                Hint { keycap: "⏎"; label: "log in"; onClicked: root.login() }
                Hint { visible: sddm.canSuspend; keycap: "◇"; label: "sleep"; onClicked: sddm.suspend() }
                Hint { visible: sddm.canReboot; keycap: "↻"; label: "reboot"; onClicked: sddm.reboot() }
                Hint { visible: sddm.canPowerOff; keycap: "⏻"; label: "shut down"; danger: true; onClicked: sddm.powerOff() }
            }
        }
    }

    // A gold keycap and its meaning; clickable.
    component Hint: Item {
        id: hint
        property string keycap
        property string label
        property bool danger: false
        signal clicked()
        implicitWidth: hintRow.implicitWidth
        implicitHeight: hintRow.implicitHeight
        Row {
            id: hintRow
            spacing: 7
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(26, cap.implicitWidth + 14)
                height: 22
                radius: 4
                color: hintMa.containsMouse ? root.alpha(hint.danger ? root.crit : root.cyan, 0.15) : "transparent"
                border.width: 1
                border.color: root.alpha(hint.danger && hintMa.containsMouse ? root.crit : root.gold, 0.75)
                Text {
                    id: cap
                    anchors.centerIn: parent
                    text: hint.keycap
                    color: hint.danger && hintMa.containsMouse ? root.crit : root.gold
                    font.family: root.serif
                    font.pixelSize: 12
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: hint.label
                color: root.alpha(root.ink, 0.85)
                font.family: root.serif
                font.capitalization: Font.SmallCaps
                font.letterSpacing: 1.5
                font.pixelSize: 12
            }
        }
        MouseArea {
            id: hintMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: hint.clicked()
        }
    }

    Component.onCompleted: if (root.primary) field.forceActiveFocus()
}
