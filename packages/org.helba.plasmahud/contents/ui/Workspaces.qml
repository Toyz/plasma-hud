import QtQuick
import QtQuick.Effects
import org.kde.taskmanager as TaskManager

// Workspaces as live window maps: one frame per virtual desktop, drawn at the shape of
// the whole multi-screen span, its windows as blocks where they really are (active in
// gold, minimized faded). Click a frame to go there; drag a block onto another frame
// to send that window to that desktop. Wheel steps through desktops. The + slot at the
// end opens a new desktop; a hovered frame shows a close mark (middle-click works too).
Item {
    id: ws

    required property QtObject hud
    property real size: 30
    property var demo: null    // dev renders: { count, current, windows: ListModel }

    TaskManager.VirtualDesktopInfo { id: vd }
    TaskManager.ActivityInfo { id: activities }
    TaskManager.TasksModel {
        id: all
        groupMode: TaskManager.TasksModel.GroupDisabled
        sortMode: TaskManager.TasksModel.SortManual
        activity: activities.currentActivity
        filterByActivity: true
    }

    readonly property int count: demo ? demo.count : vd.numberOfDesktops
    readonly property int current: demo ? demo.current : Math.max(0, vd.desktopIds.indexOf(vd.currentDesktop))
    readonly property var windowModel: demo ? demo.windows : all

    // The span of all screens, in global coordinates.
    readonly property rect span: {
        const ss = Qt.application.screens;
        let x0 = 1e9, y0 = 1e9, x1 = -1e9, y1 = -1e9;
        for (let i = 0; i < ss.length; i++) {
            x0 = Math.min(x0, ss[i].virtualX); y0 = Math.min(y0, ss[i].virtualY);
            x1 = Math.max(x1, ss[i].virtualX + ss[i].width); y1 = Math.max(y1, ss[i].virtualY + ss[i].height);
        }
        return ss.length ? Qt.rect(x0, y0, x1 - x0, y1 - y0) : Qt.rect(0, 0, 1920, 1080);
    }
    readonly property real frameH: Math.round(size * 0.86)
    readonly property real frameW: Math.round(frameH * span.width / span.height)
    readonly property real gap: Math.round(size * 0.22)

    readonly property real addW: Math.round(frameH * 0.72)
    implicitWidth: count * frameW + count * gap + addW
    implicitHeight: size

    // KWin's old setCurrentDesktop(int) is a no-op on Plasma 6; set the manager's
    // `current` property to the desktop's id instead.
    function activate(i) {
        if (demo || i < 0 || i >= count || i === current) return;
        ws.hud.switchDesktop(vd.desktopIds[i], vd.desktopNames[i]);
    }
    function frameAt(x) {
        const i = Math.floor(x / (frameW + gap));
        return x - i * (frameW + gap) <= frameW ? i : -1;
    }
    function add() {
        if (!demo) ws.hud.addArea(count);
    }
    function remove(i) {
        if (demo || count <= 1 || i < 0 || i >= count) return;
        ws.hud.removeArea(vd.desktopIds[i]);
    }
    function sendTo(row, desk) {
        if (demo || desk < 0 || desk >= count) return;
        all.requestVirtualDesktops(all.makeModelIndex(row), [vd.desktopIds[desk]]);
    }

    Row {
        id: frames
        anchors.verticalCenter: parent.verticalCenter
        spacing: ws.gap

        Repeater {
            model: ws.count
            Item {
                id: frame
                required property int index
                readonly property bool on: index === ws.current
                readonly property string deskId: ws.demo ? String(index) : (vd.desktopIds[index] || "")
                width: ws.frameW
                height: ws.frameH

                Rectangle {
                    anchors.fill: parent
                    radius: 2
                    color: ws.hud.alpha(ws.hud.glassBottom, frame.on ? 0.95 : 0.7)
                    border.width: 1
                    border.color: ws.hud.alpha(ws.hud.gold, frame.on ? 1 : frameMa.containsMouse ? 0.75 : 0.35)
                    layer.enabled: frame.on && ws.hud.glow > 0
                    layer.effect: MultiEffect {
                        shadowEnabled: true
                        shadowColor: ws.hud.gold
                        shadowBlur: 0.5
                        shadowHorizontalOffset: 0
                        shadowVerticalOffset: 0
                    }
                }
                // Screen seams.
                Repeater {
                    model: Qt.application.screens.length
                    Rectangle {
                        required property int index
                        readonly property var sc: Qt.application.screens[index]
                        visible: sc.virtualX > ws.span.x
                        x: (sc.virtualX - ws.span.x) / ws.span.width * frame.width
                        y: 2
                        width: 1
                        height: frame.height - 4
                        color: ws.hud.alpha(ws.hud.gold, 0.15)
                    }
                }

                // This desktop's windows.
                Item {
                    id: winLayer
                    anchors.fill: parent
                    anchors.margins: 1
                    clip: true
                    Repeater {
                        model: ws.windowModel
                        Rectangle {
                            id: win
                            required property int index
                            required property var model
                            readonly property rect g: model.Geometry || Qt.rect(0, 0, 0, 0)
                            readonly property bool here: !model.IsLauncher && !model.IsStartup && g.width > 0
                                && (model.IsOnAllVirtualDesktops || String(model.VirtualDesktops || "").split(",").indexOf(frame.deskId) >= 0)
                            visible: here
                            z: model.StackingOrder || 0
                            x: (g.x - ws.span.x) / ws.span.width * parent.width
                            y: (g.y - ws.span.y) / ws.span.height * parent.height
                            width: Math.max(2, g.width / ws.span.width * parent.width)
                            height: Math.max(2, g.height / ws.span.height * parent.height)
                            color: model.IsActive ? ws.hud.alpha(ws.hud.gold, 0.85)
                                : ws.hud.alpha(ws.hud.cyan, model.IsMinimized ? 0.12 : 0.35)
                            border.width: 1
                            border.color: model.IsActive ? ws.hud.gold : ws.hud.alpha(ws.hud.cyan, model.IsMinimized ? 0.3 : 0.75)
                            opacity: frameMa.dragged === win ? 0.5 : 1
                        }
                    }
                }

                // One handler on top: click switches, drag a window block to another frame
                // to move that window there.
                MouseArea {
                    id: frameMa
                    anchors.fill: parent
                    z: 10
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                    cursorShape: dragged ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                    property Item pressedOn: null
                    property Item dragged: null
                    property point origin
                    onPressed: mouse => {
                        if (mouse.button === Qt.MiddleButton) {
                            ws.remove(frame.index);
                            return;
                        }
                        origin = Qt.point(mouse.x, mouse.y);
                        const p = mapToItem(winLayer, mouse.x, mouse.y);
                        let hit = null;
                        for (let i = winLayer.children.length - 1; i >= 0; i--) {
                            const c = winLayer.children[i];
                            if (c.visible && c.here && p.x >= c.x && p.x <= c.x + c.width && p.y >= c.y && p.y <= c.y + c.height
                                    && (!hit || c.z >= hit.z)) hit = c;
                        }
                        pressedOn = hit;
                    }
                    onPositionChanged: mouse => {
                        if (pressed && pressedOn && !dragged && Math.hypot(mouse.x - origin.x, mouse.y - origin.y) > 5)
                            dragged = pressedOn;
                    }
                    onReleased: mouse => {
                        if (mouse.button === Qt.MiddleButton) return;
                        if (dragged) {
                            const p = mapToItem(frames, mouse.x, mouse.y);
                            const target = ws.frameAt(p.x);
                            if (target !== frame.index) ws.sendTo(dragged.index, target);
                        } else {
                            ws.activate(frame.index);
                        }
                        dragged = null;
                        pressedOn = null;
                    }
                }

                // Close mark, top right, while hovered.
                Item {
                    id: closer
                    readonly property real s: Math.max(9, Math.round(ws.frameH * 0.42))
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 1
                    width: s
                    height: s
                    z: 11
                    visible: ws.count > 1 && !frameMa.dragged && (frameMa.containsMouse || closeMa.containsMouse)
                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.s * 0.72
                        height: width
                        rotation: 45
                        color: closeMa.containsMouse ? ws.hud.crit : ws.hud.glassBottom
                        border.width: 1
                        border.color: closeMa.containsMouse ? ws.hud.crit : ws.hud.alpha(ws.hud.gold, 0.85)
                    }
                    Text {
                        anchors.centerIn: parent
                        text: "×"
                        color: closeMa.containsMouse ? ws.hud.ink : ws.hud.gold
                        font.pixelSize: Math.round(parent.s * 0.75)
                        font.weight: Font.Bold
                    }
                    MouseArea {
                        id: closeMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ws.remove(frame.index)
                    }
                }

                Text {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.rightMargin: 3
                    anchors.bottomMargin: 1
                    text: frame.index + 1
                    color: ws.hud.alpha(frame.on ? ws.hud.gold : ws.hud.inkDim, 0.9)
                    font.family: ws.hud.serifFont
                    font.pixelSize: Math.max(7, Math.round(ws.size * 0.28))
                    font.weight: Font.DemiBold
                }
            }
        }
    }

    // Open a new desktop: a dashed ghost frame with a gold +.
    Item {
        id: addSlot
        x: frames.x + frames.width + ws.gap
        anchors.verticalCenter: parent.verticalCenter
        width: ws.addW
        height: ws.frameH
        Rectangle {
            anchors.fill: parent
            radius: 2
            color: ws.hud.alpha(ws.hud.glassBottom, addMa.containsMouse ? 0.85 : 0.45)
            border.width: 1
            border.color: ws.hud.alpha(addMa.containsMouse ? ws.hud.cyan : ws.hud.gold, addMa.containsMouse ? 0.9 : 0.3)
        }
        Text {
            anchors.centerIn: parent
            text: "+"
            color: addMa.containsMouse ? ws.hud.cyan : ws.hud.alpha(ws.hud.gold, 0.75)
            font.family: ws.hud.serifFont
            font.pixelSize: Math.round(ws.frameH * 0.62)
        }
        MouseArea {
            id: addMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: ws.add()
        }
    }

    WheelHandler {
        property real acc: 0
        onWheel: event => {
            acc += event.angleDelta.y;
            if (Math.abs(acc) < 120) return;
            const step = acc > 0 ? -1 : 1;
            acc = 0;
            ws.activate((ws.current + step + ws.count) % ws.count);
        }
    }
}
