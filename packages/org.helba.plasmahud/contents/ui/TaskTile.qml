import QtQuick
import QtQuick.Effects
import org.kde.kirigami as Kirigami

// One task in the strip. No frame of its own: the island is the frame. A gold diamond
// under the icon marks the active window (cyan and pulsing when it wants attention);
// small ◇ marks show open windows (hollow when minimized).
Item {
    id: t

    required property QtObject hud
    required property var model
    required property int index
    property real tileH: 30
    property bool vertical: false
    property bool showTitle: false
    property bool dragging: false
    property bool hovered: false

    readonly property bool active: !!model.IsActive
    readonly property bool minimized: !!model.IsMinimized
    readonly property bool launcher: !!model.IsLauncher
    readonly property bool startup: !!model.IsStartup
    readonly property bool attention: !!model.IsDemandingAttention
    readonly property int windows: model.IsGroupParent ? (model.ChildCount || 0) : (launcher ? 0 : 1)
    readonly property real iconSize: Math.round(tileH * 0.6)
    readonly property real cellW: Math.round(tileH * 1.1)
    readonly property string title: model.display || model.AppName || ""
    readonly property real titleW: (showTitle && active && !vertical) ? Math.min(200, Math.ceil(titleMetrics.advanceWidth) + 8) : 0
    readonly property color tone: attention ? hud.cyan : hud.gold

    width: vertical ? tileH : cellW + titleW
    height: tileH
    opacity: dragging ? 0.4 : 1
    Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

    TextMetrics {
        id: titleMetrics
        font: titleText.font
        text: t.title
    }

    // Hover / active wash: cyan light rising from below.
    Rectangle {
        anchors.fill: parent
        anchors.topMargin: 2
        anchors.bottomMargin: 2
        radius: 4
        opacity: t.active ? 1 : t.hovered ? 0.6 : 0
        Behavior on opacity { NumberAnimation { duration: 140 } }
        gradient: Gradient {
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 1.0; color: t.hud.alpha(t.hud.cyan, 0.22) }
        }
    }

    Kirigami.Icon {
        id: icon
        x: Math.round((t.cellW - width) / 2)
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -1
        width: t.iconSize
        height: width
        source: t.model.decoration
        opacity: t.launcher ? 0.55 : t.minimized ? 0.4 : 1
        scale: t.hovered ? 1.08 : 1
        Behavior on scale { NumberAnimation { duration: 120 } }
        layer.enabled: t.minimized || t.launcher
        layer.effect: MultiEffect { saturation: -1.0 }

        SequentialAnimation on opacity {
            running: t.startup
            loops: Animation.Infinite
            NumberAnimation { to: 0.3; duration: 450 }
            NumberAnimation { to: 1.0; duration: 450 }
        }
    }

    Text {
        id: titleText
        x: t.cellW - 4
        anchors.verticalCenter: parent.verticalCenter
        width: t.titleW - 6
        visible: t.titleW > 0
        elide: Text.ElideRight
        text: t.title
        color: t.hud.alpha(t.hud.text, 0.9)
        font.family: t.hud.serifFont
        font.capitalization: Font.SmallCaps
        font.pixelSize: Math.max(10, Math.round(t.tileH * 0.36))
        font.letterSpacing: 1
    }

    // Diamond: active window or demanding attention.
    Rectangle {
        x: Math.round((t.cellW - width) / 2)
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 1
        width: t.active || t.attention ? 6 : 0
        height: width
        rotation: 45
        color: t.tone
        Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        layer.enabled: width > 0 && t.hud.glow > 0
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: t.tone
            shadowBlur: 0.5
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
        }
        SequentialAnimation on opacity {
            running: t.attention
            loops: Animation.Infinite
            alwaysRunToEnd: true
            NumberAnimation { to: 0.25; duration: 420 }
            NumberAnimation { to: 1.0; duration: 420 }
        }
    }

    // ◇ marks for running, inactive tasks (hollow when minimized).
    Row {
        x: Math.round((t.cellW - width) / 2)
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 2
        spacing: 3
        visible: !t.active && !t.attention && t.windows > 0
        Repeater {
            model: Math.min(3, t.windows)
            Rectangle {
                width: 4
                height: 4
                rotation: 45
                color: t.minimized ? "transparent" : t.hud.alpha(t.hud.cyan, 0.7)
                border.width: 1
                border.color: t.hud.alpha(t.minimized ? t.hud.inkDim : t.hud.cyan, 0.8)
            }
        }
    }

    // Group count, as a superscript.
    Text {
        visible: t.windows > 1
        x: Math.round(t.cellW / 2 + t.iconSize / 2 - 2)
        y: 1
        text: t.windows
        color: t.hud.gold
        font.family: t.hud.serifFont
        font.pixelSize: Math.max(7, Math.round(t.tileH * 0.26))
        font.weight: Font.Bold
    }
}
