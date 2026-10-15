import QtQuick

// A command key in The World's style: glass plate, gold rule, small-caps serif label.
// With holdMs > 0 it must be held until the charge line fills.
Item {
    id: b

    required property QtObject hud
    property string label: ""
    property string code: ""
    property int holdMs: 0
    property color tone: hud.gold
    property real progress: 0
    signal triggered

    readonly property bool hot: ma.containsMouse || progress > 0

    implicitWidth: Math.max(56, txt.implicitWidth + 22)
    implicitHeight: 38

    Rectangle {
        anchors.fill: parent
        radius: 4
        gradient: Gradient {
            GradientStop { position: 0.0; color: b.hud.glassTop }
            GradientStop { position: 1.0; color: b.hud.glassBottom }
        }
        border.width: 1
        border.color: b.hud.alpha(b.tone, b.hot ? 0.95 : 0.4)
        Behavior on border.color { ColorAnimation { duration: 120 } }
    }
    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: 3
        color: b.hud.alpha(b.hud.cyan, ma.pressed ? 0.18 : b.hot ? 0.08 : 0)
    }

    // Hold charge.
    Rectangle {
        x: 6
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 4
        width: (parent.width - 12) * b.progress
        height: 1
        color: b.tone
        visible: b.holdMs > 0
    }

    Column {
        anchors.centerIn: parent
        spacing: -1
        Text {
            id: txt
            anchors.horizontalCenter: parent.horizontalCenter
            text: b.label
            color: b.hot ? b.hud.ink : b.hud.alpha(b.tone, 0.9)
            font.family: b.hud.serifFont
            font.capitalization: Font.SmallCaps
            font.pixelSize: 12
            font.letterSpacing: 1
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: b.holdMs > 0
            text: "hold"
            color: b.hud.inkDim
            font.family: b.hud.serifFont
            font.italic: true
            font.pixelSize: 8
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: if (b.holdMs > 0) {
            drain.stop();
            charge.restart();
        }
        onReleased: if (b.holdMs > 0 && charge.running) {
            charge.stop();
            drain.restart();
        }
        onCanceled: if (b.holdMs > 0) {
            charge.stop();
            drain.restart();
        }
        onClicked: if (b.holdMs === 0) b.triggered()
    }

    NumberAnimation {
        id: charge
        target: b
        property: "progress"
        to: 1
        duration: b.holdMs * (1 - b.progress)
        onFinished: if (b.progress >= 0.999) {
            b.progress = 0;
            b.triggered();
        }
    }
    NumberAnimation {
        id: drain
        target: b
        property: "progress"
        to: 0
        duration: 220
        easing.type: Easing.OutQuad
    }
}
