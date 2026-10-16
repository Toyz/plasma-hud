pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import org.kde.kirigami as Kirigami
import org.kde.layershell as LayerShell
import org.kde.notificationmanager as NotificationManager
import org.kde.taskmanager as TaskManager
import plasma.applet.org.kde.plasma.notifications as Stock

// The .hack notification popups. Plasma's notifications applet (in the system tray) keeps
// the server, history, do-not-disturb and sounds; this borrows its popup model from the
// applet's shared Globals and switches the applet's own popup windows off, then draws
// each notice as a glass plate stacked up from the bottom right of the active screen.
// Loaded through a Loader: if the applet module is not there, the import fails, nothing
// here exists and the stock popups keep working.
Item {
    id: note

    property QtObject hud
    readonly property QtObject globals: Stock.Globals
    readonly property NotificationManager.Notifications popups: globals.popupNotificationsModel
    readonly property var settings: globals.notificationSettings

    visible: false

    Component.onCompleted: globals.popupInstantiator.active = false
    Component.onDestruction: globals.popupInstantiator.active = true

    // notificationIds already announced (sound hint, timeout taken over)
    property var seen: ({})

    function idx(i) { return popups.index(i, 0); }
    function ago(d) {
        const s = Math.max(0, (hud.now - d) / 1000);
        if (s < 60) return "now";
        if (s < 3600) return Math.floor(s / 60) + "m";
        return Math.floor(s / 3600) + "h";
    }
    function isImage(u) { return /\.(png|jpe?g|webp|gif|bmp)$/i.test(String(u)); }

    Window {
        id: win
        readonly property int pad: 14
        property int shownHeight: 1
        width: 420 + pad * 2
        height: shownHeight
        color: "transparent"
        flags: Qt.FramelessWindowHint
        visible: list.count > 0 || linger.running

        LayerShell.Window.scope: "org.helba.notify"
        LayerShell.Window.layer: LayerShell.Window.LayerTop
        LayerShell.Window.anchors: LayerShell.Window.AnchorBottom | LayerShell.Window.AnchorRight
        LayerShell.Window.margins.right: 8
        LayerShell.Window.margins.bottom: 8
        LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityNone
        LayerShell.Window.exclusionZone: 0
        LayerShell.Window.wantsToBeOnActiveScreen: true

        Timer { id: linger; interval: 420 }

        ListView {
            id: list
            x: win.pad
            y: win.pad
            width: 420
            height: Math.min(contentHeight, (win.screen ? win.screen.height : 1080) * 0.8)
            onHeightChanged: if (count > 0) win.shownHeight = Math.max(1, height + win.pad * 2)
            onCountChanged: {
                if (count > 0) win.shownHeight = Math.max(1, height + win.pad * 2);
                else linger.restart();
            }
            model: note.popups
            verticalLayoutDirection: ListView.BottomToTop
            spacing: 10
            interactive: false
            cacheBuffer: 100000

            add: Transition {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 260 }
                NumberAnimation { property: "x"; from: 60; to: 0; duration: 380; easing.type: Easing.OutCubic }
            }
            remove: Transition {
                NumberAnimation { property: "opacity"; to: 0; duration: 300 }
                NumberAnimation { property: "x"; to: 40; duration: 300; easing.type: Easing.InCubic }
            }
            displaced: Transition {
                NumberAnimation { properties: "x,y"; duration: 260; easing.type: Easing.OutCubic }
            }

            delegate: Item {
                id: card

                required property int index
                required property var model

                readonly property bool isJob: model.type === NotificationManager.Notifications.JobType
                readonly property bool critical: model.urgency === NotificationManager.Notifications.CriticalUrgency
                readonly property bool resident: model.resident
                readonly property bool hasSomeActions: model.hasDefaultAction || (model.actionLabels || []).length > 0 || model.hasReplyAction
                readonly property var picture: model.image || model.iconName || ""
                readonly property string thumb: {
                    const u = model.urls || [];
                    return u.length > 0 && note.isImage(u[0]) ? String(u[0]) : "";
                }
                property var fallbackWindow: null

                // Timeouts as the stock popup has them: -1 means the user's default; running
                // jobs auto-dismiss unless jobs are set to stay; 0 stays until closed.
                readonly property int defaultTimeout: note.settings.popupTimeout + (thumb ? 5000 : 0)
                readonly property int dismissTimeout: !note.settings.permanentJobPopups && isJob
                                                      && model.jobState !== NotificationManager.Notifications.JobStateStopped
                                                      ? defaultTimeout : 0
                readonly property int effectiveTimeout: model.timeout === -1 ? defaultTimeout
                                                      : dismissTimeout ? dismissTimeout : model.timeout

                width: 420
                height: plate.implicitHeight

                function close() { note.popups.close(note.idx(index)); }
                function done() {
                    if (resident) model.expired = true;
                    else close();
                }
                function activate() {
                    if (fallbackWindow && fallbackWindow.valid) {
                        note.globals.tasksModel.requestActivate(fallbackWindow);
                        if (!resident) close();
                        return;
                    }
                    if (model.hasDefaultAction)
                        note.popups.invokeDefaultAction(note.idx(index), resident ? NotificationManager.Notifications.None
                                                                                  : NotificationManager.Notifications.Close);
                }
                function invoke(name) {
                    note.popups.invokeAction(note.idx(index), name, resident ? NotificationManager.Notifications.None
                                                                             : NotificationManager.Notifications.Close);
                }
                function expire() {
                    if (dismissTimeout) {
                        model.dismissed = true;
                    } else if (resident || (hasSomeActions && !model.transient)) {
                        model.expired = true;
                    } else {
                        note.popups.expire(note.idx(index));
                    }
                }

                Component.onCompleted: {
                    const id = model.notificationId;
                    if (note.seen[id]) return;
                    note.seen[id] = true;
                    if (note.globals.inhibited) model.wasAddedDuringInhibition = false;
                    if (model.type === NotificationManager.Notifications.NotificationType && model.desktopEntry) {
                        if (!model.notifyRcName) {
                            note.settings.registerKnownApplication(model.desktopEntry);
                            note.settings.save();
                        }
                        // No default action: clicking brings the app's window up instead.
                        if (!model.hasDefaultAction) {
                            const tasks = note.globals.tasksModel;
                            for (let i = 0; i < tasks.rowCount(); ++i) {
                                const appId = tasks.data(tasks.index(i, 0), TaskManager.AbstractTasksModel.AppId);
                                if (appId === model.desktopEntry + ".desktop") {
                                    fallbackWindow = tasks.makePersistentModelIndex(i);
                                    break;
                                }
                            }
                        }
                    }
                    note.popups.stopTimeout(note.idx(index));
                    note.popups.playSoundHint(note.idx(index));
                }

                HoverHandler {
                    id: hover
                    onHoveredChanged: if (hovered) card.model.read = true
                }
                TapHandler {
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                    onTapped: (point, button) => {
                        if (button === Qt.MiddleButton) card.close();
                        else card.activate();
                    }
                }
                Timer {
                    id: timer
                    interval: card.effectiveTimeout
                    running: interval > 0 && !hover.hovered && win.visible
                    onTriggered: card.expire()
                }

                Item {
                    id: plate
                    anchors.fill: parent
                    implicitHeight: body.implicitHeight + 30

                    HackFrame {
                        anchors.fill: parent
                        hud: note.hud
                        radius: 6
                        stud: 6
                    }
                    // Critical notices carry a red rule down the left edge.
                    Rectangle {
                        visible: card.critical
                        x: 3
                        y: 10
                        width: 2
                        height: parent.height - 20
                        color: note.hud.crit
                    }

                    Column {
                        id: body
                        x: 16
                        y: 14
                        width: parent.width - 32
                        spacing: 8

                        // Header: app badge, app name, age, close.
                        Item {
                            width: parent.width
                            height: 22
                            Rectangle {
                                id: appDiamond
                                anchors.verticalCenter: parent.verticalCenter
                                x: 3
                                width: 15
                                height: 15
                                rotation: 45
                                color: note.hud.alpha(note.hud.cyan, 0.08)
                                border.width: 1
                                border.color: card.critical ? note.hud.crit : note.hud.gold
                            }
                            Kirigami.Icon {
                                anchors.centerIn: appDiamond
                                width: 12
                                height: 12
                                source: card.model.applicationIconName || ""
                            }
                            Text {
                                anchors.left: appDiamond.right
                                anchors.leftMargin: 10
                                anchors.right: age.left
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                text: card.model.applicationName || (card.isJob ? "Transfer" : "Notice")
                                elide: Text.ElideRight
                                color: card.critical ? note.hud.crit : note.hud.gold
                                font.family: note.hud.serifFont
                                font.capitalization: Font.SmallCaps
                                font.letterSpacing: 1.5
                                font.pixelSize: 13
                            }
                            Text {
                                id: age
                                anchors.right: closeMark.left
                                anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                text: card.isJob ? Math.max(0, card.model.percentage) + "%"
                                                 : note.ago(isNaN(card.model.updated) ? card.model.created : card.model.updated)
                                color: note.hud.inkDim
                                font.family: note.hud.serifFont
                                font.pixelSize: 12
                            }
                            // Close: a small diamond with a cross, gold on hover.
                            Item {
                                id: closeMark
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                width: 20
                                height: 20
                                readonly property color tone: closeHover.hovered ? note.hud.gold : note.hud.inkDim
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 13
                                    height: 13
                                    rotation: 45
                                    color: closeHover.hovered ? note.hud.alpha(note.hud.gold, 0.15) : "transparent"
                                    border.width: 1
                                    border.color: closeMark.tone
                                }
                                Repeater {
                                    model: [45, -45]
                                    Rectangle {
                                        required property int modelData
                                        anchors.centerIn: parent
                                        width: 7
                                        height: 1.4
                                        rotation: modelData
                                        color: closeMark.tone
                                    }
                                }
                                HoverHandler { id: closeHover }
                                TapHandler { onTapped: card.close() }
                            }
                        }

                        // Picture beside the summary and body.
                        Item {
                            width: parent.width
                            height: Math.max(textCol.implicitHeight, pic.visible ? pic.height : 0)

                            Rectangle {
                                id: pic
                                visible: picIcon.valid && !card.isJob
                                width: 52
                                height: 52
                                radius: 3
                                color: note.hud.alpha(note.hud.cyan, 0.06)
                                border.width: 1
                                border.color: note.hud.alpha(note.hud.gold, 0.7)
                                Kirigami.Icon {
                                    id: picIcon
                                    anchors.fill: parent
                                    anchors.margins: 4
                                    source: card.picture
                                }
                            }

                            Column {
                                id: textCol
                                anchors.left: pic.visible ? pic.right : parent.left
                                anchors.leftMargin: pic.visible ? 12 : 0
                                anchors.right: parent.right
                                spacing: 4

                                Text {
                                    width: parent.width
                                    visible: text.length > 0
                                    text: card.model.summary || ""
                                    textFormat: Text.PlainText
                                    wrapMode: Text.Wrap
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                    color: note.hud.ink
                                    font.family: note.hud.serifFont
                                    font.pixelSize: 15
                                }
                                Text {
                                    width: parent.width
                                    visible: text.length > 0
                                    text: card.isJob && card.model.jobDetails
                                          ? (card.model.jobDetails.descriptionValue1 || card.model.body || "")
                                          : (card.model.body || "")
                                    textFormat: Text.StyledText
                                    wrapMode: Text.Wrap
                                    maximumLineCount: 6
                                    elide: Text.ElideRight
                                    color: note.hud.alpha(note.hud.ink, 0.78)
                                    linkColor: note.hud.cyan
                                    font.pixelSize: 13
                                    onLinkActivated: link => {
                                        Qt.openUrlExternally(link);
                                        card.done();
                                    }
                                }
                            }
                        }

                        // Screenshot / image attachments.
                        Rectangle {
                            visible: card.thumb.length > 0
                            width: parent.width
                            height: visible ? 120 : 0
                            radius: 3
                            color: "transparent"
                            border.width: 1
                            border.color: note.hud.alpha(note.hud.gold, 0.6)
                            clip: true
                            Image {
                                anchors.fill: parent
                                anchors.margins: 1
                                source: card.thumb
                                sourceSize.width: 420
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                            }
                            TapHandler {
                                onTapped: {
                                    Qt.openUrlExternally(card.thumb);
                                    card.done();
                                }
                            }
                        }

                        // Job progress: a row of diamond cells.
                        Row {
                            visible: card.isJob
                            spacing: 3
                            readonly property int cells: 26
                            readonly property real full: Math.max(0, card.model.percentage) / 100 * cells
                            Repeater {
                                model: parent.cells
                                Item {
                                    required property int index
                                    readonly property real lit: Math.max(0, Math.min(1, parent.full - index))
                                    width: 11
                                    height: 12
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 7
                                        height: 7
                                        rotation: 45
                                        color: parent.lit > 0 ? note.hud.alpha(note.hud.cyan, 0.35 + 0.65 * parent.lit)
                                                              : note.hud.alpha(note.hud.inkDim, 0.18)
                                        border.width: 1
                                        border.color: note.hud.alpha(note.hud.cyan, parent.lit > 0 ? 0.9 : 0.25)
                                    }
                                }
                            }
                        }

                        // Actions as gold-ruled chips.
                        Flow {
                            width: parent.width
                            spacing: 6
                            visible: chips.count > 0
                            Repeater {
                                id: chips
                                model: {
                                    const out = [];
                                    if (card.isJob) {
                                        if (card.model.jobState === NotificationManager.Notifications.JobStateRunning && card.model.suspendable)
                                            out.push({ name: "#suspend", label: "Pause" });
                                        if (card.model.jobState === NotificationManager.Notifications.JobStateSuspended)
                                            out.push({ name: "#resume", label: "Resume" });
                                        if (card.model.jobState !== NotificationManager.Notifications.JobStateStopped && card.model.killable)
                                            out.push({ name: "#kill", label: "Cancel" });
                                    }
                                    const names = card.model.actionNames || [];
                                    const labels = card.model.actionLabels || [];
                                    for (let i = 0; i < names.length; ++i)
                                        out.push({ name: names[i], label: labels[i] || names[i] });
                                    return out;
                                }
                                Rectangle {
                                    id: chip
                                    required property var modelData
                                    width: chipText.implicitWidth + 22
                                    height: 24
                                    radius: 2
                                    color: chipHover.hovered ? note.hud.gold : note.hud.alpha(note.hud.gold, 0.08)
                                    border.width: 1
                                    border.color: note.hud.alpha(note.hud.gold, chipHover.hovered ? 1 : 0.65)
                                    Text {
                                        id: chipText
                                        anchors.centerIn: parent
                                        text: chip.modelData.label
                                        color: chipHover.hovered ? note.hud.onGold : note.hud.gold
                                        font.family: note.hud.serifFont
                                        font.capitalization: Font.SmallCaps
                                        font.letterSpacing: 1
                                        font.pixelSize: 12
                                    }
                                    HoverHandler { id: chipHover }
                                    TapHandler {
                                        onTapped: {
                                            const n = chip.modelData.name;
                                            const i = note.idx(card.index);
                                            if (n === "#suspend") note.popups.suspendJob(i);
                                            else if (n === "#resume") note.popups.resumeJob(i);
                                            else if (n === "#kill") note.popups.killJob(i);
                                            else card.invoke(n);
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Time left: a thin cyan line draining along the bottom edge.
                    Rectangle {
                        id: drain
                        visible: timer.interval > 0 && note.settings.showPopupTimeout
                        x: 12
                        y: parent.height - 5
                        height: 1.5
                        property real remain: 1
                        width: (parent.width - 24) * remain
                        color: note.hud.alpha(note.hud.cyan, 0.7)
                        NumberAnimation on remain {
                            from: 1
                            to: 0
                            duration: timer.interval
                            running: timer.running
                        }
                    }
                }
            }
        }
    }
}
