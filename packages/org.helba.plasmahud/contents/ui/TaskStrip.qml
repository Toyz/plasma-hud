import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.taskmanager as TaskManager

// The task strip: TasksModel-backed tiles with drag reordering, wheel cycling,
// hover previews and a HUD context menu.
Item {
    id: strip

    implicitWidth: list.width
    implicitHeight: list.height

    required property QtObject hud
    property bool vertical: false

    // Sized by the island it sits in: tiles are as tall as the strip.
    property real tileH: 30
    readonly property int spacing: Math.max(2, Math.round(tileH * 0.08))
    readonly property alias model: tasks
    // Dev renders only: a ListModel with the same role names, since KWin will not hand
    // window data to anything but plasmashell.
    property var demoModel: null

    readonly property real naturalLength: vertical ? list.height : list.width

    property Item hoveredTile: null
    property bool previewHovered: false
    property int dragFrom: -1

    // Screen membership. TasksModel's own screen filter drops minimized windows (KWin
    // stops reporting them on their screen), so each strip remembers where it last saw
    // every window while it was visible and keeps it there when minimized.
    readonly property bool perScreen: !!hud.cfg.currentScreenOnly
    readonly property rect screenRect: Plasmoid.containment ? Plasmoid.containment.screenGeometry : Qt.rect(0, 0, 0, 0)
    property var lastScreenOf: ({})

    function sameRect(a, b) {
        return !!a && !!b && a.width > 0 && a.x === b.x && a.y === b.y && a.width === b.width && a.height === b.height;
    }
    // Launches started from this strip (launcher url -> when). The "starting" placeholder
    // and the fresh window have no screen yet; without this every strip hid them for a
    // moment and the tile blinked out and back in.
    property var launches: ({})
    function noteLaunch(m) {
        const url = String(m.LauncherUrlWithoutIcon || "");
        if (!url) return;
        const next = Object.assign({}, launches);
        next[url] = Date.now();
        launches = next;
    }
    function launchedHere(m) {
        const t = launches[String(m.LauncherUrlWithoutIcon || "")];
        return !!t && Date.now() - t < 20000;
    }
    function owns(m) {
        if (!perScreen || m.IsLauncher) return true;
        if (m.IsStartup) return launchedHere(m);
        const id = (m.WinIdList || [])[0] || "";
        const sg = m.ScreenGeometry;
        if (!m.IsMinimized && sg && sg.width > 0) {
            const mine = sameRect(sg, screenRect);
            if (id) lastScreenOf[id] = mine;
            return mine;
        }
        if (id in lastScreenOf) return lastScreenOf[id];
        // No screen reported yet: go by the window's own geometry, else keep the slot on
        // the strip that launched it.
        const g = m.Geometry;
        if (g && g.width > 0) {
            const cx = g.x + g.width / 2, cy = g.y + g.height / 2;
            return cx >= screenRect.x && cx < screenRect.x + screenRect.width
                && cy >= screenRect.y && cy < screenRect.y + screenRect.height;
        }
        return launchedHere(m);
    }

    TaskManager.VirtualDesktopInfo { id: desktops }
    TaskManager.ActivityInfo { id: activities }

    TaskManager.TasksModel {
        id: tasks
        sortMode: TaskManager.TasksModel.SortManual
        // Per-screen strips do their own screen filtering (see `owns`), so a group could
        // span screens; keep windows separate there.
        groupMode: strip.hud.cfg.groupTasks && !strip.perScreen ? TaskManager.TasksModel.GroupApplications
                                                                 : TaskManager.TasksModel.GroupDisabled
        groupInline: false
        separateLaunchers: false
        hideActivatedLaunchers: true
        launchInPlace: true
        virtualDesktop: desktops.currentDesktop
        activity: activities.currentActivity
        screenGeometry: strip.screenRect
        filterByVirtualDesktop: !!strip.hud.cfg.currentDesktopOnly
        filterByScreen: false
        filterByActivity: true
        // KWin marks minimized windows hidden; filtering hidden ones drops them from the bar.
        filterHidden: false
        launcherList: strip.hud.cfg.launchers || []

        onLauncherListChanged: {
            const saved = strip.hud.cfg.launchers || [];
            if (launcherList.join("\n") !== saved.join("\n"))
                strip.hud.cfg.launchers = launcherList;
        }
    }

    function indexOf(i) { return tasks.makeModelIndex(i); }

    function activate(tile) {
        const idx = indexOf(tile.index);
        const m = tile.model;
        if (m.IsLauncher) {
            noteLaunch(m);
            tasks.requestActivate(idx);
        } else if (m.IsGroupParent) {
            if (m.IsActive) cycleGroup(tile.index, m.ChildCount);
            else tasks.requestActivate(idx);
        } else if (m.IsActive && !m.IsMinimized) {
            tasks.requestToggleMinimized(idx);
        } else {
            tasks.requestActivate(idx);
        }
    }

    function cycleGroup(row, n) {
        let cur = -1;
        for (let i = 0; i < n; i++) {
            if (tasks.data(tasks.makeModelIndex(row, i), TaskManager.AbstractTasksModel.IsActive)) {
                cur = i;
                break;
            }
        }
        tasks.requestActivate(tasks.makeModelIndex(row, (cur + 1) % n));
    }

    function cycleAll(dir) {
        const n = tasks.count;
        if (n === 0) return;
        let cur = -1;
        for (let i = 0; i < n; i++) {
            const idx = tasks.makeModelIndex(i);
            if (tasks.data(idx, TaskManager.AbstractTasksModel.IsActive)) { cur = i; break; }
        }
        for (let k = 1; k <= n; k++) {
            const i = ((cur < 0 ? 0 : cur) + dir * k + n * k) % n;
            const idx = tasks.makeModelIndex(i);
            if (!tasks.data(idx, TaskManager.AbstractTasksModel.IsLauncher)) {
                tasks.requestActivate(idx);
                return;
            }
        }
    }

    function publishGeometry(tile) {
        if (!tile || tile.launcher) return;
        const p = tile.mapToGlobal(0, 0);
        tasks.requestPublishDelegateGeometry(indexOf(tile.index), Qt.rect(p.x, p.y, tile.width, tile.height), tile);
    }

    // Tiles.
    Grid {
        id: list
        x: strip.vertical ? Math.round((strip.width - width) / 2) : 0
        y: strip.vertical ? 0 : Math.round((strip.height - height) / 2)
        flow: strip.vertical ? Grid.TopToBottom : Grid.LeftToRight
        columns: strip.vertical ? 1 : 0
        rows: strip.vertical ? 0 : 1
        spacing: strip.spacing

        move: Transition {
            NumberAnimation { properties: "x,y"; duration: 180; easing.type: Easing.OutCubic }
        }

        Repeater {
            model: strip.demoModel || tasks
            TaskTile {
                id: tile
                hud: strip.hud
                tileH: strip.tileH
                vertical: strip.vertical
                showTitle: !!strip.hud.cfg.showActiveTitle
                dragging: strip.dragFrom === index
                hovered: area.containsMouse
                visible: strip.owns(tile.model)
                onXChanged: geomTimer.restart()
                onWidthChanged: geomTimer.restart()

                Timer {
                    id: geomTimer
                    interval: 300
                    onTriggered: strip.publishGeometry(tile)
                }

                MouseArea {
                    id: area
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                    property point pressPos
                    property bool moved: false

                    onContainsMouseChanged: {
                        if (containsMouse) {
                            strip.hoveredTile = tile;
                            hideTimer.stop();
                            if (!preview.visible) showTimer.restart();
                        } else {
                            showTimer.stop();
                            hideTimer.restart();
                        }
                    }
                    onPressed: mouse => {
                        pressPos = Qt.point(mouse.x, mouse.y);
                        moved = false;
                        showTimer.stop();
                        preview.visible = false;
                    }
                    onPositionChanged: mouse => {
                        if (!pressed || !(mouse.buttons & Qt.LeftButton)) return;
                        if (!moved && Math.hypot(mouse.x - pressPos.x, mouse.y - pressPos.y) > 8) {
                            moved = true;
                            strip.dragFrom = tile.index;
                        }
                        if (!moved) return;
                        const p = mapToItem(list, mouse.x, mouse.y);
                        const target = list.childAt(p.x, p.y);
                        if (target && target.index !== undefined && target.index !== strip.dragFrom
                                && !target.launcher === !tile.launcher) {
                            tasks.move(strip.dragFrom, target.index);
                            strip.dragFrom = target.index;
                        }
                    }
                    onReleased: {
                        if (moved) {
                            strip.dragFrom = -1;
                            tasks.syncLaunchers();
                        }
                    }
                    onClicked: mouse => {
                        if (moved) return;
                        if (mouse.button === Qt.LeftButton) strip.activate(tile);
                        else if (mouse.button === Qt.MiddleButton) { strip.noteLaunch(tile.model); tasks.requestNewInstance(strip.indexOf(tile.index)); }
                        else if (mouse.button === Qt.RightButton) menu.openFor(tile);
                    }
                }
            }
        }
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        property real acc: 0
        onWheel: event => {
            acc += event.angleDelta.y || event.angleDelta.x;
            while (acc >= 120) { acc -= 120; strip.cycleAll(-1); }
            while (acc <= -120) { acc += 120; strip.cycleAll(1); }
        }
    }

    Timer {
        id: showTimer
        interval: 450
        onTriggered: if (strip.hoveredTile && !strip.hoveredTile.launcher && strip.dragFrom < 0) {
            preview.visualParent = strip.hoveredTile;
            preview.visible = true;
        }
    }
    Timer {
        id: hideTimer
        interval: 280
        onTriggered: if (!strip.previewHovered) {
            preview.visible = false;
            strip.hoveredTile = null;
        }
    }

    PlasmaCore.Dialog {
        id: preview
        location: Plasmoid.location
        type: PlasmaCore.Dialog.Tooltip
        backgroundHints: PlasmaCore.Dialog.NoBackground
        flags: Qt.WindowDoesNotAcceptFocus
        mainItem: TaskPreview {
            hud: strip.hud
            tasks: tasks
            tile: strip.hoveredTile
            live: preview.visible && !!strip.hud.cfg.livePreviews
            onHoveredChanged: {
                strip.previewHovered = hovered;
                if (hovered) hideTimer.stop();
                else hideTimer.restart();
            }
            onDone: {
                preview.visible = false;
                strip.previewHovered = false;
            }
        }
    }

    TaskMenu {
        id: menu
        hud: strip.hud
        tasks: tasks
        onLaunching: m => strip.noteLaunch(m)
    }
}
