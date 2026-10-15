import QtQuick
import QtQuick.Layouts

// What this widget instance shows in the panel. Each mode is a floating island:
//   2  tasks     the task strip, centered in the space the panel gives it
//   3  left      launcher glyph + workspace pips
//   4  right     wraps the stock tray before it, then clock + telemetry
// Older layouts: 0 = tasks + plated badge, 1 = plated badge only.
Item {
    id: bar

    required property QtObject hud
    property bool vertical: false
    property var demoTasks: null
    property var demoDesktops: null
    property int modeOverride: -1   // dev renders: several modes sharing one config
    readonly property int mode: modeOverride >= 0 ? modeOverride : (hud.cfg.mode || 0)
    readonly property bool fills: mode === 0 || mode === 2
    readonly property real thick: vertical ? width : height
    readonly property real islandH: Math.max(20, Math.round(thick) - 2)
    readonly property real natural: body.item ? body.item.implicitWidth : 0
    // Where the HUD popup anchors.
    readonly property Item popupAnchor: body.item && body.item.anchorItem ? body.item.anchorItem : bar
    readonly property bool showBadge: mode === 0 || mode === 1 || mode === 4
    signal badgeActivated
    signal launcherRequested

    // Launcher anchors: the left island's glyph when this is the left island, and the
    // bar's left edge as a fallback for panels without one.
    readonly property Item launcherAnchor: body.item && body.item.glyph ? body.item.glyph : edgeAnchor
    readonly property Item edgeAnchor: edge
    Item {
        id: edge
        x: 0
        width: 1
        height: parent.height
    }

    Layout.fillWidth: !vertical && fills
    Layout.fillHeight: vertical && fills
    Layout.minimumWidth: vertical ? 0 : natural
    Layout.preferredWidth: vertical ? -1 : natural
    Layout.maximumWidth: vertical || fills ? Number.POSITIVE_INFINITY : natural
    Layout.minimumHeight: vertical ? natural : 0
    Layout.preferredHeight: vertical ? natural : -1
    Layout.maximumHeight: !vertical || fills ? Number.POSITIVE_INFINITY : natural

    component Sep: Rectangle {
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        width: 1
        height: Math.round(bar.islandH * 0.6)
        rotation: 18
        color: bar.hud.alpha(bar.hud.gold, 0.35)
    }

    Loader {
        id: body
        anchors.fill: parent
        sourceComponent: [both, badgeOnly, tasksIsland, leftIsland, rightIsland][Math.max(0, Math.min(4, bar.mode))]
    }

    Component {
        id: tasksIsland
        Item {
            implicitWidth: strip.implicitWidth > 0 ? isl.implicitWidth : 0
            Island {
                id: isl
                hud: bar.hud
                visible: strip.implicitWidth > 0
                height: bar.islandH
                anchors.centerIn: parent
                width: implicitWidth
                TaskStrip {
                    id: strip
                    hud: bar.hud
                    tileH: bar.islandH - 4
                    height: tileH
                    demoModel: bar.demoTasks
                }
            }
        }
    }

    Component {
        id: leftIsland
        Island {
            readonly property Item glyph: glyphButton
            hud: bar.hud
            height: bar.islandH
            anchors.verticalCenter: parent ? parent.verticalCenter : undefined
            LauncherButton {
                id: glyphButton
                hud: bar.hud
                size: bar.islandH - 4
                onClicked: bar.launcherRequested()
            }
            Sep {}
            Workspaces {
                hud: bar.hud
                size: bar.islandH - 4
                demo: bar.demoDesktops
            }
        }
    }

    Component {
        id: rightIsland
        Island {
            id: r
            readonly property Item anchorItem: r
            hud: bar.hud
            wrapPrevious: !bar.demoTasks
            height: bar.islandH
            anchors.verticalCenter: parent ? parent.verticalCenter : undefined
            Clock {
                hud: bar.hud
                size: bar.islandH - 4
                onClicked: bar.badgeActivated()
            }
            Sep {}
            Pulse {
                hud: bar.hud
                size: bar.islandH - 4
                onClicked: bar.badgeActivated()
            }
        }
    }

    Component {
        id: badgeOnly
        Badge {
            readonly property Item anchorItem: this
            hud: bar.hud
            vertical: bar.vertical
            implicitWidth: vertical ? 0 : naturalWidth
            onActivated: bar.badgeActivated()
        }
    }

    Component {
        id: both
        RowLayout {
            readonly property Item anchorItem: badge
            implicitWidth: strip.naturalLength + 8 + badge.naturalWidth
            spacing: 8
            TaskStrip {
                id: strip
                hud: bar.hud
                tileH: bar.islandH - 4
                Layout.fillWidth: true
                Layout.fillHeight: true
                demoModel: bar.demoTasks
            }
            Badge {
                id: badge
                hud: bar.hud
                Layout.fillHeight: true
                onActivated: bar.badgeActivated()
            }
        }
    }
}
