import QtQuick
import QtQuick.Shapes
import org.kde.kirigami as Kirigami
import org.kde.plasma.private.sessions as Sessions
import org.kde.plasma.private.keyboardindicator as KeyboardIndicator

// Helba World lock screen (.hack, The World). Idle: a large serif clock over the
// wallpaper (which the greeter draws behind us) with the Chaos Gate sigil turning
// faintly. Any key or movement raises the log-in plate: avatar in a gold diamond,
// a glass password field, the greeter's messages. One instance runs per screen; the
// typed password is shared through the Pass singleton.
//
// The greeter talks to this file through `authenticator`, `kscreenlocker_userName`
// and `kscreenlocker_userImage`, and looks for viewVisible / notification /
// clearPassword on the root.
Item {
    id: root

    property bool debug: false
    property string notification
    signal clearPassword()
    signal notificationRepeated()
    property bool viewVisible: false

    implicitWidth: 800
    implicitHeight: 600

    // ------------------------------------------------------------ palette

    readonly property bool light: Kirigami.Theme.backgroundColor.hslLightness > 0.5
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

    // ------------------------------------------------------------ state

    property bool active: false        // the log-in plate is up
    property bool failedRecently: false
    readonly property bool busy: Pass.text.length > 0

    function wake() {
        if (!active) {
            active = true;
            authenticator.startAuthenticating();
        }
        idle.restart();
        field.forceActiveFocus();
    }
    function say(msg) {
        if (!msg) return;
        if (root.notification.includes(msg)) root.notificationRepeated();
        else root.notification = root.notification ? root.notification + "\n" + msg : msg;
        clearNote.restart();
    }

    onClearPassword: Pass.text = ""

    Timer {
        id: idle
        interval: 12000
        onTriggered: if (!root.busy) root.active = false
    }
    Timer {
        id: clearNote
        interval: 4000
        onTriggered: root.notification = ""
    }
    // After a failure, a short pause before the next try (like the default greeter).
    Timer {
        id: grace
        interval: 2500
        onTriggered: {
            root.failedRecently = false;
            authenticator.startAuthenticating();
        }
    }

    Connections {
        target: authenticator
        function onFailed(kind) {
            if (kind !== 0) return;     // fingerprint / smartcard attempts report on their own
            root.say("The gate did not open. Try again.");
            Pass.text = "";
            root.failedRecently = true;
            grace.restart();
            shake.restart();
        }
        function onSucceeded() { Qt.quit(); }
        function onInfoMessageChanged() { root.say(authenticator.infoMessage); }
        function onErrorMessageChanged() { root.say(authenticator.errorMessage); }
        function onPromptChanged() { root.say(authenticator.prompt); }
        function onPromptForSecretChanged() { field.forceActiveFocus(); }
    }

    Sessions.SessionManagement { id: session }
    Connections {
        target: session
        function onAboutToSuspend() { Pass.text = ""; }
    }
    KeyboardIndicator.KeyState {
        id: caps
        key: Qt.Key_CapsLock
    }

    // ------------------------------------------------------------ input

    MouseArea {
        id: input
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.active ? Qt.ArrowCursor : Qt.BlankCursor
        property point last: Qt.point(-1, -1)
        onPositionChanged: mouse => {
            // The first event after showing is the cursor appearing, not a movement.
            if (last.x >= 0 && (Math.abs(mouse.x - last.x) > 2 || Math.abs(mouse.y - last.y) > 2)) root.wake();
            last = Qt.point(mouse.x, mouse.y);
        }
        onPressed: root.wake()
        focus: true
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                Pass.text = "";
                root.active = false;
                event.accepted = true;
                return;
            }
            const first = !root.active;
            root.wake();
            // The key that woke the screen also counts as typing.
            if (first && event.text && event.text.charCodeAt(0) >= 32) {
                Pass.text += event.text;
                event.accepted = true;
            }
        }
    }

    // ------------------------------------------------------------ veil + sigil

    Rectangle {
        anchors.fill: parent
        color: root.glass
        // Light: the wallpaper (drawn by the greeter behind us) stays the main thing.
        opacity: root.active ? 0.45 : 0.12
        Behavior on opacity { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
    }

    Item {
        id: sigil
        readonly property real d: Math.min(root.width, root.height) * 0.62
        x: (root.width - d) / 2
        y: (root.height - d) / 2
        width: d
        height: d
        opacity: root.active ? 0.5 : 0.22
        Behavior on opacity { NumberAnimation { duration: 600 } }
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
        id: clock
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.active ? root.height * 0.08 : root.height * 0.36
        scale: root.active ? 0.55 : 1
        transformOrigin: Item.Top
        spacing: 2
        Behavior on y { NumberAnimation { duration: 480; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 480; easing.type: Easing.OutCubic } }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            Text {
                text: Qt.formatTime(root.now, "HH")
                color: root.ink
                font.family: root.serif
                font.pixelSize: 132
                font.weight: Font.Light
                style: Text.Raised
                styleColor: root.alpha(root.glass, 0.55)
            }
            Text {
                text: ":"
                color: root.gold
                opacity: root.now.getSeconds() % 2 ? 0.55 : 1
                font.family: root.serif
                font.pixelSize: 132
                font.weight: Font.Light
                style: Text.Raised
                styleColor: root.alpha(root.glass, 0.55)
            }
            Text {
                text: Qt.formatTime(root.now, "mm")
                color: root.ink
                font.family: root.serif
                font.pixelSize: 132
                font.weight: Font.Light
                style: Text.Raised
                styleColor: root.alpha(root.glass, 0.55)
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
            font.pixelSize: 22
        }
    }

    // ------------------------------------------------------------ log-in plate

    Item {
        id: plate
        width: Math.min(520, root.width - 64)
        height: col.implicitHeight + 64
        x: (root.width - width) / 2 + shakeX
        y: root.height * 0.5 - height / 2 + (root.active ? 0 : 30)
        opacity: root.active ? 1 : 0
        visible: opacity > 0
        property real shakeX: 0
        Behavior on opacity { NumberAnimation { duration: 360 } }
        Behavior on y { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }

        SequentialAnimation {
            id: shake
            NumberAnimation { target: plate; property: "shakeX"; to: -14; duration: 50 }
            NumberAnimation { target: plate; property: "shakeX"; to: 12; duration: 70 }
            NumberAnimation { target: plate; property: "shakeX"; to: -8; duration: 60 }
            NumberAnimation { target: plate; property: "shakeX"; to: 4; duration: 50 }
            NumberAnimation { target: plate; property: "shakeX"; to: 0; duration: 50 }
        }

        // Glass, gold edge with an inner echo, diamond studs.
        Rectangle {
            anchors.fill: parent
            radius: 6
            gradient: Gradient {
                GradientStop { position: 0; color: root.alpha(root.glassTop, 0.72) }
                GradientStop { position: 1; color: root.alpha(root.glass, 0.8) }
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

            // Avatar in a gold diamond.
            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 104
                height: 104
                Item {
                    anchors.centerIn: parent
                    width: 74
                    height: 74
                    rotation: 45
                    clip: true
                    Rectangle { anchors.fill: parent; color: root.alpha(root.cyan, 0.12) }
                    Image {
                        anchors.centerIn: parent
                        width: 106
                        height: 106
                        rotation: -45
                        fillMode: Image.PreserveAspectCrop
                        smooth: true
                        source: kscreenlocker_userImage
                            ? "file://" + kscreenlocker_userImage.split("/").map(encodeURIComponent).join("/") : ""
                    }
                    Text {
                        anchors.centerIn: parent
                        rotation: -45
                        visible: !kscreenlocker_userImage
                        text: (kscreenlocker_userName || "?").charAt(0).toUpperCase()
                        color: root.gold
                        font.family: root.serif
                        font.pixelSize: 34
                    }
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: 76
                    height: 76
                    rotation: 45
                    color: "transparent"
                    border.width: 1.5
                    border.color: root.gold
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Welcome back, " + (kscreenlocker_userName || "traveller")
                color: root.ink
                font.family: root.serif
                font.italic: true
                font.pixelSize: 16
            }

            // Password field.
            Item {
                width: parent.width
                height: 46
                opacity: root.failedRecently ? 0.5 : 1
                Rectangle {
                    anchors.fill: parent
                    radius: 4
                    color: root.alpha(root.well, 0.7)
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
                    text: Pass.text
                    onTextEdited: Pass.text = text
                    echoMode: TextInput.Password
                    passwordCharacter: "◆"
                    passwordMaskDelay: 0
                    enabled: !root.failedRecently
                    color: root.ink
                    selectionColor: root.alpha(root.cyan, 0.4)
                    font.family: root.serif
                    font.pixelSize: 17
                    font.letterSpacing: 3
                    clip: true
                    onAccepted: {
                        if (text.length || !authenticator.hadPrompt) authenticator.respond(text);
                    }
                    Keys.onEscapePressed: {
                        Pass.text = "";
                        root.active = false;
                    }
                    onTextChanged: idle.restart()
                }
                Text {
                    anchors.left: field.left
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !field.text
                    text: authenticator.prompt || "Enter your password"
                    color: root.inkDim
                    font.family: root.serif
                    font.italic: true
                    font.pixelSize: 14
                }
            }

            // Messages: failures in red, the rest quiet; caps lock warning.
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                visible: text.length > 0
                text: root.notification + (caps.locked ? (root.notification ? "\n" : "") + "Caps Lock is on" : "")
                color: root.notification.indexOf("did not open") >= 0 ? root.crit : root.inkDim
                font.family: root.serif
                font.italic: true
                font.pixelSize: 13
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 18
                Hint { keycap: "⏎"; label: "log in" }
                Hint { keycap: "Esc"; label: "hide" }
                Hint {
                    visible: session.canSuspend
                    keycap: "◇"
                    label: "sleep"
                    clickable: true
                    onClicked: session.suspend()
                }
            }
        }
    }

    // A gold keycap and its meaning; optionally a button.
    component Hint: Item {
        id: hint
        property string keycap
        property string label
        property bool clickable: false
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
                color: hintMa.containsMouse ? root.alpha(root.cyan, 0.15) : "transparent"
                border.width: 1
                border.color: root.alpha(root.gold, 0.75)
                Text {
                    id: cap
                    anchors.centerIn: parent
                    text: hint.keycap
                    color: root.gold
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
            enabled: hint.clickable
            hoverEnabled: hint.clickable
            cursorShape: hint.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: hint.clicked()
        }
    }
}
