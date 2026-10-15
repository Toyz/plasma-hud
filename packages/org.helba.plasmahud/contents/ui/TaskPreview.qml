import QtQuick
import QtQml.Models
import org.kde.kirigami as Kirigami
import org.kde.pipewire as PipeWire
import org.kde.taskmanager as TaskManager

// Hover card for a task: live PipeWire thumbnails of each window, click to focus,
// middle-click or the X to close.
Item {
    id: card

    required property QtObject hud
    required property var tasks
    property Item tile: null
    property bool live: true
    readonly property bool hovered: hover.hovered
    signal done

    readonly property bool group: !!(tile && tile.model.IsGroupParent)
    readonly property int row: tile ? tile.index : -1
    readonly property int shown: Math.min(6, group ? tile.model.ChildCount : 1)
    readonly property int cardW: 240
    readonly property int cardH: 168

    width: Math.max(cardW, shown * cardW + (shown - 1) * 8) + 34
    height: cardH + 69

    HoverHandler { id: hover }

    HackFrame {
        anchors.fill: parent
        anchors.margins: 5
        anchors.bottomMargin: 10
        hud: card.hud
        radius: 6
        stud: 6
    }

    Row {
        x: 17
        y: 15
        spacing: 8
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "◆"
            color: card.hud.cyan
            font.pixelSize: 9
        }
        Text {
            text: card.tile ? (card.tile.model.AppName || card.tile.model.display || "") : ""
            color: card.hud.gold
            font.family: card.hud.serifFont
            font.capitalization: Font.SmallCaps
            font.pixelSize: 14
            font.letterSpacing: 2
        }
        Text {
            anchors.baseline: parent.children[1].baseline
            text: card.group ? card.tile.model.ChildCount + " windows" : ""
            color: card.hud.inkDim
            font.family: card.hud.serifFont
            font.italic: true
            font.pixelSize: 10
        }
    }

    DelegateModel {
        id: children
        model: card.group ? card.tasks : null
        rootIndex: card.group ? card.tasks.makeModelIndex(card.row) : card.tasks.makeModelIndex(-1)
        delegate: WindowCard {
            required property var model
            required property int index
            title: model.display || ""
            winId: (model.WinIdList || [])[0] || ""
            icon: model.decoration
            active: !!model.IsActive
            minimized: !!model.IsMinimized
            modelIndex: card.tasks.makeModelIndex(card.row, index)
            visible: index < 6
        }
    }

    Row {
        x: 17
        y: 41
        spacing: 8
        Repeater { model: card.group ? children : null }
        WindowCard {
            visible: !card.group && card.tile !== null
            title: card.tile ? card.tile.model.display || "" : ""
            winId: card.tile ? (card.tile.model.WinIdList || [])[0] || "" : ""
            icon: card.tile ? card.tile.model.decoration : ""
            active: card.tile ? !!card.tile.model.IsActive : false
            minimized: card.tile ? !!card.tile.model.IsMinimized : false
            modelIndex: card.tasks.makeModelIndex(card.row)
        }
    }

    component WindowCard: Item {
        id: wc
        property string title
        property var winId
        property var icon
        property bool active
        property bool minimized
        property var modelIndex

        width: card.cardW
        height: card.cardH

        Rectangle {
            anchors.fill: parent
            radius: 4
            color: card.hud.alpha(card.hud.cyan, ma.containsMouse ? 0.10 : 0.03)
            border.width: 1
            border.color: wc.active ? card.hud.gold : card.hud.alpha(card.hud.gold, ma.containsMouse ? 0.7 : 0.25)
        }

        Item {
            id: shot
            x: 6
            y: 6
            width: parent.width - 12
            height: parent.height - 34
            clip: true

            TaskManager.ScreencastingRequest {
                id: cast
                uuid: card.live && wc.winId ? wc.winId : ""
            }
            PipeWire.PipeWireSourceItem {
                id: pw
                anchors.fill: parent
                nodeId: cast.nodeId
                objectSerial: cast.objectSerial
                visible: card.live && nodeId > 0
                opacity: wc.minimized ? 0.5 : 1
            }
            Kirigami.Icon {
                anchors.centerIn: parent
                width: 56
                height: 56
                source: wc.icon
                visible: !pw.visible || !pw.ready
                opacity: 0.8
            }
            // Scanline wash over the thumbnail.
            Canvas {
                anchors.fill: parent
                visible: card.hud.cfg.scanlines
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    ctx.fillStyle = "rgba(0,0,0,0.16)";
                    for (let y = 0; y < height; y += 3) ctx.fillRect(0, y, width, 1);
                }
            }
        }

        Text {
            x: 8
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 8
            width: parent.width - 34
            elide: Text.ElideRight
            text: wc.title
            color: wc.active ? card.hud.text : card.hud.alpha(card.hud.text, 0.75)
            font.family: card.hud.labelFont
            font.pixelSize: 10
        }

        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
            onClicked: mouse => {
                if (mouse.button === Qt.MiddleButton) card.tasks.requestClose(wc.modelIndex);
                else card.tasks.requestActivate(wc.modelIndex);
                card.done();
            }
        }

        // Close key.
        Item {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 4
            width: 20
            height: 20
            Rectangle {
                anchors.fill: parent
                radius: 3
                color: card.hud.alpha(card.hud.crit, closeMa.containsMouse ? 0.3 : 0.0)
                border.width: 1
                border.color: card.hud.alpha(card.hud.crit, closeMa.containsMouse ? 1 : 0.4)
            }
            Text {
                anchors.centerIn: parent
                text: "×"
                color: card.hud.crit
                font.family: card.hud.serifFont
                font.pixelSize: 14
            }
            MouseArea {
                id: closeMa
                anchors.fill: parent
                hoverEnabled: true
                onClicked: {
                    card.tasks.requestClose(wc.modelIndex);
                    card.done();
                }
            }
        }
    }
}
