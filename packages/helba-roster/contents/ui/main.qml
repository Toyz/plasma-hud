import QtQuick
import QtQuick.Layouts
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.kwin as KWin

// Alt+Tab: the party roster. Each window is a member line (app icon in a diamond,
// title, app and area); the line you are on gets the cyan wash and gold brackets of
// the Chaos Gate, and the right side shows that window live. Runs inside KWin, so it
// carries its own small copy of the Helba World palette (light or dark from the KDE
// color scheme) instead of the HUD's shared context.
KWin.TabBoxSwitcher {
    id: tabBox

    readonly property bool light: Kirigami.Theme.backgroundColor.hslLightness > 0.5
    readonly property color gold: light ? "#8a6418" : "#b8935a"
    readonly property color cyan: light ? "#14708a" : "#8fe3ff"
    readonly property color ink: light ? "#1a2033" : "#eaf0fb"
    readonly property color inkDim: light ? "#5a6380" : "#8d98b6"
    readonly property color well: light ? "#e9e2cf" : "#070b1a"
    readonly property string serif: "Noto Serif"
    function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a); }

    currentIndex: (instantiator.object as RosterDialog)?.currentIndex ?? currentIndex

    Instantiator {
        id: instantiator
        active: tabBox.visible
        delegate: RosterDialog {}
    }

    component RosterDialog: PlasmaCore.Dialog {
        id: dialog
        property alias currentIndex: list.currentIndex
        location: PlasmaCore.Types.Floating
        visible: tabBox.visible
        flags: Qt.Popup | Qt.X11BypassWindowManagerHint
        x: tabBox.screenGeometry.x + (tabBox.screenGeometry.width - mainItem.width) / 2
        y: tabBox.screenGeometry.y + (tabBox.screenGeometry.height - mainItem.height) / 2

        mainItem: Item {
            id: body
            readonly property int rowH: 48
            readonly property int rows: Math.min(Math.max(1, list.count), 9)
            readonly property real previewW: Math.round(Math.min(380, tabBox.screenGeometry.width * 0.22))
            width: 440 + previewW + 30
            height: 44 + rows * rowH + 12

            // Header: ◆ Party · n members
            RowLayout {
                id: header
                x: 6
                width: list.width
                height: 34
                spacing: 8
                Text { text: "◆"; color: tabBox.cyan; font.pixelSize: 10 }
                Text {
                    text: "Party"
                    color: tabBox.gold
                    font.family: tabBox.serif
                    font.capitalization: Font.SmallCaps
                    font.letterSpacing: 2
                    font.pixelSize: 17
                }
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: tabBox.alpha(tabBox.gold, 0.55) }
                        GradientStop { position: 1; color: "transparent" }
                    }
                }
                Text {
                    text: list.count + (list.count === 1 ? " member" : " members")
                    color: tabBox.inkDim
                    font.family: tabBox.serif
                    font.italic: true
                    font.pixelSize: 11
                }
            }

            ListView {
                id: list
                x: 0
                y: header.height + 8
                width: 440
                height: body.rows * body.rowH
                clip: true
                model: tabBox.model
                currentIndex: tabBox.currentIndex
                keyNavigationWraps: true
                highlightMoveDuration: 120
                boundsBehavior: Flickable.StopAtBounds
                focus: true

                highlight: Item {
                    // Cyan wash with gold brackets, like the Chaos Gate's chosen line.
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 2
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: tabBox.alpha(tabBox.cyan, 0.24) }
                            GradientStop { position: 1; color: tabBox.alpha(tabBox.cyan, 0.05) }
                        }
                    }
                    Bracket { anchors.left: parent.left }
                    Bracket { anchors.right: parent.right; flip: true }
                }

                delegate: Item {
                    id: row
                    required property int index
                    required property var model
                    readonly property bool on: ListView.isCurrentItem
                    width: list.width
                    height: body.rowH

                    // Diamond badge with the app icon.
                    Item {
                        id: badge
                        x: 14
                        anchors.verticalCenter: parent.verticalCenter
                        width: 34
                        height: 34
                        Rectangle {
                            anchors.centerIn: parent
                            width: 24
                            height: 24
                            rotation: 45
                            color: row.on ? tabBox.alpha(tabBox.gold, 0.18) : "transparent"
                            border.width: 1
                            border.color: tabBox.alpha(tabBox.gold, row.on ? 0.95 : 0.5)
                        }
                        Kirigami.Icon {
                            anchors.centerIn: parent
                            width: 22
                            height: 22
                            source: row.model.icon
                        }
                    }
                    Column {
                        anchors.left: badge.right
                        anchors.leftMargin: 12
                        anchors.right: number.left
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1
                        Text {
                            width: parent.width
                            text: row.model.caption
                            elide: Text.ElideMiddle
                            color: tabBox.ink
                            opacity: row.model.minimized ? 0.6 : 1
                            font.family: tabBox.serif
                            font.pixelSize: 14
                        }
                        Text {
                            width: parent.width
                            text: (row.model.minimized ? "resting  ·  " : "") + (row.model.desktopName || "")
                            elide: Text.ElideRight
                            color: tabBox.inkDim
                            font.family: tabBox.serif
                            font.italic: true
                            font.pixelSize: 10
                        }
                    }
                    Text {
                        id: number
                        anchors.right: parent.right
                        anchors.rightMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        text: row.index < 9 ? String(row.index + 1) : ""
                        color: row.on ? tabBox.gold : tabBox.alpha(tabBox.inkDim, 0.7)
                        font.family: tabBox.serif
                        font.pixelSize: 12
                    }

                    TapHandler {
                        onSingleTapped: {
                            if (row.index === list.currentIndex) list.model.activate(row.index);
                            else list.currentIndex = row.index;
                        }
                        onDoubleTapped: list.model.activate(row.index)
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: list.count === 0
                    text: "No one in the party"
                    color: tabBox.inkDim
                    font.family: tabBox.serif
                    font.italic: true
                }
            }

            // Live view of the window you are on.
            Item {
                id: preview
                x: list.width + 22
                y: list.y
                width: body.previewW
                height: list.height
                Rectangle {
                    anchors.fill: parent
                    color: tabBox.well
                    border.width: 1
                    border.color: tabBox.alpha(tabBox.gold, 0.45)
                }
                KWin.WindowThumbnail {
                    anchors.fill: parent
                    anchors.margins: 8
                    wId: list.currentItem ? list.currentItem.model.windowId : ""
                    visible: list.count > 0
                }
                // Corner studs.
                Repeater {
                    model: 4
                    Rectangle {
                        required property int index
                        width: 7
                        height: 7
                        rotation: 45
                        color: tabBox.gold
                        x: (index % 2 ? preview.width : 0) - width / 2
                        y: (index < 2 ? 0 : preview.height) - height / 2
                    }
                }
            }

            Connections {
                target: tabBox
                function onCurrentIndexChanged() { list.currentIndex = tabBox.currentIndex; }
            }

            // Arrow keys move too (Tab cycling comes from KWin).
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Up) list.decrementCurrentIndex();
                else if (event.key === Qt.Key_Down) list.incrementCurrentIndex();
            }
        }

        onSceneGraphError: () => {
            // Intentionally empty: QtQuick may otherwise qFatal on a graphics reset.
        }
    }

    component Bracket: Item {
        property bool flip: false
        width: 9
        height: parent.height - 4
        y: 2
        Rectangle { x: parent.flip ? parent.width - 1.5 : 0; width: 1.5; height: parent.height; color: tabBox.gold }
        Rectangle { x: parent.flip ? 1 : 0; width: 8; height: 1.5; color: tabBox.gold }
        Rectangle { x: parent.flip ? 1 : 0; y: parent.height - 1.5; width: 8; height: 1.5; color: tabBox.gold }
    }
}
