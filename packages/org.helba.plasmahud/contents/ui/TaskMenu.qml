import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore

// HUD-styled right-click menu for a task tile.
PlasmaCore.Dialog {
    id: menu

    required property QtObject hud
    required property var tasks
    property Item tile: null
    signal launching(var model)

    location: Plasmoid.location
    type: PlasmaCore.Dialog.PopupMenu
    backgroundHints: PlasmaCore.Dialog.NoBackground
    hideOnWindowDeactivate: true

    function openFor(t) {
        tile = t;
        visualParent = t;
        visible = true;
        requestActivate();
    }

    readonly property var m: tile ? tile.model : ({})
    readonly property bool pinned: !!tile && tasks.launcherPosition(m.LauncherUrlWithoutIcon) >= 0
    readonly property var entries: {
        if (!tile) return [];
        const e = [];
        if (m.IsLauncher) {
            e.push({ key: "launch", label: "Launch" });
        } else {
            if (m.CanLaunchNewInstance) e.push({ key: "new", label: "New instance" });
            e.push({ key: "min", label: m.IsMinimized ? "Restore" : "Minimize" });
            if (!m.IsGroupParent) {
                if (m.IsMaximizable) e.push({ key: "max", label: m.IsMaximized ? "Unmaximize" : "Maximize" });
                e.push({ key: "above", label: m.IsKeepAbove ? "Stop keeping above" : "Keep above" });
                if (m.IsFullScreenable) e.push({ key: "full", label: m.IsFullScreen ? "Exit fullscreen" : "Fullscreen" });
            }
        }
        e.push({ key: "pin", label: pinned ? "Unpin" : "Pin to the bar" });
        if (!m.IsLauncher) e.push({ key: "close", label: m.IsGroupParent ? "Close all" : "Close", crit: true });
        return e;
    }

    function trigger(key) {
        const idx = tasks.makeModelIndex(tile.index);
        switch (key) {
        case "launch": menu.launching(m); tasks.requestActivate(idx); break;
        case "new": menu.launching(m); tasks.requestNewInstance(idx); break;
        case "min": tasks.requestToggleMinimized(idx); break;
        case "max": tasks.requestToggleMaximized(idx); break;
        case "above": tasks.requestToggleKeepAbove(idx); break;
        case "full": tasks.requestToggleFullScreen(idx); break;
        case "pin":
            if (pinned) tasks.requestRemoveLauncher(m.LauncherUrlWithoutIcon);
            else tasks.requestAddLauncher(m.LauncherUrlWithoutIcon);
            break;
        case "close": tasks.requestClose(idx); break;
        }
        visible = false;
    }

    mainItem: FocusScope {
        width: 220
        height: col.implicitHeight + 39
        focus: true
        Keys.onEscapePressed: menu.visible = false

        HackFrame {
            anchors.fill: parent
            anchors.margins: 5
            anchors.bottomMargin: 10
            hud: menu.hud
            radius: 5
            stud: 5
        }

        Column {
            id: col
            x: 13
            y: 17
            width: parent.width - 26
            spacing: 2

            Text {
                x: 6
                text: menu.tile ? (menu.m.AppName || menu.m.display || "") : ""
                color: menu.hud.gold
                font.family: menu.hud.serifFont
                font.capitalization: Font.SmallCaps
                font.pixelSize: 12
                font.letterSpacing: 2
                bottomPadding: 4
            }

            Repeater {
                model: menu.entries
                Item {
                    required property var modelData
                    required property int index
                    width: col.width
                    height: 26
                    readonly property color tone: modelData.crit ? menu.hud.crit : menu.hud.cyan

                    Rectangle {
                        anchors.fill: parent
                        color: menu.hud.alpha(parent.tone, ma.containsMouse ? 0.16 : 0)
                        Rectangle {
                            width: 2
                            height: parent.height
                            color: parent.parent.tone
                            visible: ma.containsMouse
                        }
                    }
                    Text {
                        x: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: parent.modelData.label
                        color: parent.modelData.crit ? menu.hud.crit : menu.hud.text
                        font.family: menu.hud.serifFont
                        font.capitalization: Font.SmallCaps
                        font.pixelSize: 13
                        font.letterSpacing: 1
                    }
                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: ma.containsMouse ? "◆" : "◇"
                        color: menu.hud.alpha(menu.hud.cyan, 0.8)
                        font.pixelSize: 9
                    }
                    MouseArea {
                        id: ma
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: menu.trigger(parent.modelData.key)
                    }
                }
            }
        }
    }
}
