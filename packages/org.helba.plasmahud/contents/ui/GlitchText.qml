import QtQuick

// Text that occasionally tears into RGB-split copies, like a bad signal.
Item {
    id: g

    property alias text: base.text
    property alias font: base.font
    property color color: "white"
    property color splitA: "#00f0ff"
    property color splitB: "#ff2a6d"
    property bool enabledGlitch: true
    property bool running: true

    property real _dx: 0
    property real _dy: 0
    property bool _on: false

    implicitWidth: base.implicitWidth
    implicitHeight: base.implicitHeight

    Text {
        x: g._dx * 1.6
        y: -g._dy
        visible: g._on
        text: base.text
        font: base.font
        color: g.splitB
        opacity: 0.8
    }
    Text {
        x: -g._dx
        y: g._dy
        visible: g._on
        text: base.text
        font: base.font
        color: g.splitA
        opacity: 0.8
    }
    Text {
        id: base
        x: g._on ? g._dx * 0.3 : 0
        color: g.color
    }
    // Horizontal tear: a slice of the word shifted sideways.
    Item {
        visible: g._on
        clip: true
        y: base.height * 0.45
        width: base.width
        height: base.height * 0.18
        Text {
            x: g._dx * 3
            y: -parent.y
            text: base.text
            font: base.font
            color: g.splitA
        }
    }

    Timer {
        id: idle
        running: g.running && g.enabledGlitch
        interval: 4000 + Math.random() * 5000
        onTriggered: {
            interval = 3500 + Math.random() * 6000;
            burst.frames = 4 + Math.floor(Math.random() * 5);
            burst.start();
        }
    }
    Timer {
        id: burst
        property int frames: 0
        interval: 45
        repeat: true
        onTriggered: {
            if (frames-- <= 0) {
                stop();
                g._on = false;
                g._dx = 0;
                g._dy = 0;
                return;
            }
            g._on = true;
            g._dx = (Math.random() - 0.5) * 6;
            g._dy = (Math.random() - 0.5) * 2;
        }
    }

    function kick() {
        if (!enabledGlitch) return;
        burst.frames = 7;
        burst.start();
    }
}
