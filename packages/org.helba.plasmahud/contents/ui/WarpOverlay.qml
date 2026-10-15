import QtQuick
import QtQuick.Window
import org.kde.layershell as LayerShell

// Plays a gate warp on every screen at once. play(glyph, title, fn) runs the gate out,
// calls fn under the white-out (the desktop switch), then plays the gate in with the
// area's name. A warp requested mid-warp just does its work, no second animation.
Item {
    id: warp

    required property QtObject hud
    property real t: 0
    property bool running: false
    property string glyph: ""
    property string title: ""
    property var action: null

    visible: false

    // The gate plays on the screen at the middle of the span; the others dim and flash.
    readonly property var stageScreen: {
        const ss = Qt.application.screens;
        let x0 = 1e9, x1 = -1e9, y0 = 1e9, y1 = -1e9;
        for (let i = 0; i < ss.length; i++) {
            x0 = Math.min(x0, ss[i].virtualX); x1 = Math.max(x1, ss[i].virtualX + ss[i].width);
            y0 = Math.min(y0, ss[i].virtualY); y1 = Math.max(y1, ss[i].virtualY + ss[i].height);
        }
        const cx = (x0 + x1) / 2, cy = (y0 + y1) / 2;
        for (let i = 0; i < ss.length; i++) {
            const s = ss[i];
            if (cx >= s.virtualX && cx < s.virtualX + s.width && cy >= s.virtualY && cy < s.virtualY + s.height) return s.name;
        }
        return ss.length ? ss[0].name : "";
    }

    function play(g, ti, fn) {
        if (running) {
            if (fn) fn();
            return;
        }
        glyph = g || "";
        title = ti || "";
        action = fn || null;
        t = 0;
        running = true;
        anim.restart();
    }

    SequentialAnimation {
        id: anim
        NumberAnimation { target: warp; property: "t"; from: 0; to: 1; duration: 1400; easing.type: Easing.InOutSine }
        ScriptAction { script: if (warp.action) warp.action() }
        PauseAnimation { duration: 250 }
        NumberAnimation { target: warp; property: "t"; from: 1; to: 2; duration: 1900; easing.type: Easing.Linear }
        ScriptAction { script: warp.running = false }
    }

    Instantiator {
        model: Qt.application.screens
        delegate: Window {
            required property var modelData
            // Qt picks a new window's screen from its position: start it on its own screen.
            screen: modelData
            x: modelData.virtualX
            y: modelData.virtualY
            width: modelData.width
            height: modelData.height
            color: "transparent"
            flags: Qt.FramelessWindowHint | Qt.WindowTransparentForInput
            visible: warp.running

            LayerShell.Window.scope: "org.helba.warp"
            LayerShell.Window.layer: LayerShell.Window.LayerOverlay
            LayerShell.Window.anchors: LayerShell.Window.AnchorTop | LayerShell.Window.AnchorBottom
                | LayerShell.Window.AnchorLeft | LayerShell.Window.AnchorRight
            LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityNone
            LayerShell.Window.exclusionZone: -1
            LayerShell.Window.screenConfiguration: LayerShell.Window.ScreenFromQWindow

            WarpScene {
                anchors.fill: parent
                hud: warp.hud
                stage: modelData.name === warp.stageScreen
                t: warp.t
                glyph: warp.glyph
                title: warp.title
            }
        }
    }
}
