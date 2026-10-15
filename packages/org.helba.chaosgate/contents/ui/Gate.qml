import QtQuick
import QtQuick.Window
import org.kde.layershell as LayerShell

// The gate's own surface: a Wayland overlay layer over the active screen, taking the
// keyboard while it is open.
Window {
    id: win

    required property QtObject hud
    property alias panel: panel

    color: "transparent"
    flags: Qt.FramelessWindowHint
    visible: false

    LayerShell.Window.scope: "org.helba.chaosgate"
    LayerShell.Window.layer: LayerShell.Window.LayerOverlay
    LayerShell.Window.anchors: LayerShell.Window.AnchorTop | LayerShell.Window.AnchorBottom
        | LayerShell.Window.AnchorLeft | LayerShell.Window.AnchorRight
    LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityExclusive
    LayerShell.Window.exclusionZone: -1
    LayerShell.Window.wantsToBeOnActiveScreen: true

    function open() {
        visible = true;
        requestActivate();
        panel.reset();
    }
    function close() { visible = false; }

    GatePanel {
        id: panel
        anchors.fill: parent
        hud: win.hud
        focus: true
        onCloseRequested: win.close()
    }
}
