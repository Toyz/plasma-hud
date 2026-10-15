import QtQuick
import QtQml
import QtQuick.Layouts
import QtQuick.Effects
import org.kde.kirigami as Kirigami
import org.kde.plasma.private.kicker as Kicker

// Root Town: the launcher as The World's own menu. Server glyphs across the top pick a
// category (★ pinned, ∞ all), rows are areas you can warp to, the selected one framed
// in gold 『 』. Status bars read like HP/SP. Search sits at the bottom of the frame.
//
// Keyboard: type to search, Up/Down to move, Left/Right (or Tab) to change server,
// Enter to warp, Esc to clear or close. Right-click pins / unpins.
FocusScope {
    id: lp

    required property QtObject hud
    required property var rootModel
    required property var runnerModel
    required property var favorites
    signal closeRequested
    signal command(string cmd, bool detached)
    signal editMenu

    width: 552
    height: 720

    // Tabs: 0 = pinned, 1 = frequent, 2 = all apps (root row 0), then one per category (root rows 1..).
    property int tab: 1
    readonly property bool searching: search.text.length > 0
    readonly property var categories: {
        const out = [];
        for (let i = 1; i < rootModel.count; i++) {
            const name = String(rootModel.data(rootModel.index(i, 0), Qt.DisplayRole) || "").trim();
            if (name) out.push({ row: i, name: name });
        }
        return out;
    }
    readonly property int tabCount: 3 + categories.length
    readonly property string tabName: tabTitle(tab)
    // Rows come from three places, flattened to plain entries ({ title, desc, icon,
    // storageId, src, row }):
    //   browse   the current tab's kicker model
    //   apps     every app, indexed on open and matched locally as you type: instant
    //   runner   KRunner's other answers (settings, files, math, history), merged in as
    //            they land; they never hold up the app matches
    readonly property var browseModel: tabModel(tab)

    // Plasma's own launch statistics (KActivities): most used apps first.
    Kicker.RecentUsageModel {
        id: usage
        shownItems: Kicker.RecentUsageModel.OnlyApps
        ordering: Kicker.RecentUsageModel.Popular
    }
    property var usageRows: []
    Rows {
        id: usageInst
        model: usage
        onObjectAdded: Qt.callLater(() => lp.usageRows = lp.collect(usageInst, usage))
        onObjectRemoved: Qt.callLater(() => lp.usageRows = lp.collect(usageInst, usage))
    }
    function appKey(id) { return String(id || "").replace(/^applications:/, "").replace(/\.desktop$/, "").toLowerCase(); }
    // app key -> 0..1, 1 = most used.
    readonly property var usageWeight: {
        const w = {}, n = usageRows.length;
        for (let i = 0; i < n; i++) w[appKey(usageRows[i].storageId)] = 1 - i / Math.max(1, n);
        return w;
    }
    readonly property var allModel: rootModel.count > 0 ? rootModel.modelForRow(0) : null
    readonly property var runnerRowsModel: runnerModel.count > 0 ? runnerModel.modelForRow(0) : null
    property var browseRows: []
    property var allRows: []
    property var runnerRows: []

    function collect(inst, src) {
        const out = [];
        for (let i = 0; i < inst.count; i++) {
            const o = inst.objectAt(i);
            if (o) out.push({ title: o.title, desc: o.desc, icon: o.icon, storageId: o.storageId, src: src, row: o.index });
        }
        return out;
    }
    component Rows: Instantiator {
        delegate: QtObject {
            required property var model
            required property int index
            readonly property string title: model.display || ""
            readonly property string desc: model.description || ""
            readonly property var icon: model.decoration
            readonly property string storageId: model.favoriteId || ""
        }
    }
    Rows {
        id: browseInst
        model: lp.browseModel
        onObjectAdded: Qt.callLater(() => lp.browseRows = lp.collect(browseInst, lp.browseModel))
        onObjectRemoved: Qt.callLater(() => lp.browseRows = lp.collect(browseInst, lp.browseModel))
    }
    Rows {
        id: allInst
        model: lp.allModel
        onObjectAdded: Qt.callLater(() => lp.allRows = lp.collect(allInst, lp.allModel))
        onObjectRemoved: Qt.callLater(() => lp.allRows = lp.collect(allInst, lp.allModel))
    }
    Rows {
        id: runnerInst
        model: lp.searching ? lp.runnerRowsModel : null
        onObjectAdded: Qt.callLater(() => lp.runnerRows = lp.collect(runnerInst, lp.runnerRowsModel))
        onObjectRemoved: Qt.callLater(() => lp.runnerRows = lp.collect(runnerInst, lp.runnerRowsModel))
    }

    // Name prefix beats word start beats substring beats description; shorter names win ties.
    readonly property var searchRows: {
        if (!searching) return [];
        const q = search.text.toLowerCase().trim();
        const toks = q.split(/\s+/).filter(t => t.length);
        const scored = [];
        for (const e of allRows) {
            const t = e.title.toLowerCase(), d = e.desc.toLowerCase();
            let score = 0;
            if (t.startsWith(q)) score = 100;
            else if (toks.every(k => t.split(/[\s\-_.]+/).some(w => w.startsWith(k)))) score = 70;
            else if (toks.every(k => t.indexOf(k) >= 0)) score = 40;
            else if (toks.every(k => (t + " " + d).indexOf(k) >= 0)) score = 15;
            // Usage decides between similar matches: up to +25 for the most used app.
            if (score) scored.push({ e: e, s: score + 25 * (usageWeight[appKey(e.storageId)] || 0) - t.length * 0.01 });
        }
        scored.sort((a, b) => b.s - a.s);
        const local = scored.slice(0, 8).map(x => x.e);
        const seen = {};
        for (const e of local) if (e.storageId) seen[e.storageId] = true;
        const extra = runnerRows.filter(e => !(e.storageId && seen[e.storageId])).slice(0, 12);
        return local.concat(extra);
    }
    readonly property var rowsData: searching ? searchRows : browseRows

    // The World's servers. Known categories get fixed glyphs; the rest take what's left.
    readonly property var glyphFor: ({
        "Development": "Δ", "Games": "Θ", "Graphics": "Λ", "Internet": "Σ", "Multimedia": "Ω",
        "Office": "Φ", "System": "Ψ", "Utilities": "Ξ", "Education": "Π", "Science": "Γ",
        "Settings": "Η", "Help": "Ι", "Lost & Found": "Ϟ"
    })
    function glyph(i) {
        if (i === 0) return "★";
        if (i === 1) return "↺";
        if (i === 2) return "∞";
        const c = categories[i - 3];
        return (c && glyphFor[c.name]) || "ΒΖΚΜΝΡΤΥΧ".charAt((i - 3) % 9);
    }

    function reset() {
        search.text = "";
        usage.refresh();
        tab = favorites.count > 0 ? 0 : usage.count > 0 ? 1 : 2;
        rows.currentIndex = 0;
        rows.positionViewAtBeginning();
    }
    function focusSearch() { search.forceActiveFocus(); }
    function setQuery(q) { search.text = q; }
    function step(d) { tab = (tab + d + tabCount) % tabCount; }
    function tabTitle(i) {
        return i === 0 ? "Pinned" : i === 1 ? "Frequent" : i === 2 ? "All Areas" : (categories[i - 3] || {}).name || "";
    }
    function tabModel(i) {
        return i === 0 ? favorites : i === 1 ? usage
            : i === 2 ? (rootModel.count > 0 ? rootModel.modelForRow(0) : null)
            : rootModel.modelForRow((categories[i - 3] || {}).row || 0);
    }
    function tabSize(i) {
        const m = tabModel(i);
        return m ? m.count : 0;
    }

    // The server glyph under the pointer, for the tooltip plate.
    property Item hoveredServer: null

    // An app that is already running is brought forward instead of started again;
    // Shift launches a new instance regardless.
    WindowFinder { id: finder }
    function launch(entry, shift) {
        if (!entry || !entry.src) return;
        if (shift || !entry.storageId || !finder.raiseApp(entry.storageId))
            entry.src.trigger(entry.row, "", null);
        closeRequested();
    }
    function togglePin(favoriteId) {
        if (!favoriteId) return;
        if (favorites.isFavorite(favoriteId)) favorites.removeFavorite(favoriteId);
        else favorites.addFavorite(favoriteId, -1);
    }

    Binding {
        target: lp.runnerModel
        property: "query"
        value: search.text
    }

    // Inset so the corner studs stay inside the popup window, with a gap above the bar.
    HackFrame {
        id: frame
        anchors.fill: parent
        anchors.margins: 6
        anchors.bottomMargin: 14
        hud: lp.hud
    }

    component Caps: Text {
        color: lp.hud.gold
        font.family: lp.hud.serifFont
        font.capitalization: Font.SmallCaps
        font.letterSpacing: 2
    }

    ColumnLayout {
        anchors.fill: frame
        anchors.margins: 20
        anchors.topMargin: 16
        spacing: 10

        // Server tabs.
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            opacity: lp.searching ? 0.35 : 1
            Behavior on opacity { NumberAnimation { duration: 150 } }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 1
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.15; color: lp.hud.alpha(lp.hud.gold, 0.55) }
                    GradientStop { position: 0.85; color: lp.hud.alpha(lp.hud.gold, 0.55) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }
            Row {
                anchors.centerIn: parent
                spacing: Math.max(2, Math.min(10, (parent.width - lp.tabCount * 30) / Math.max(1, lp.tabCount - 1)))
                Repeater {
                    model: lp.tabCount
                    Item {
                        id: server
                        required property int index
                        readonly property bool on: index === lp.tab
                        width: 30
                        height: 40
                        Rectangle {
                            anchors.centerIn: parent
                            width: server.on ? 26 : 20
                            height: width
                            rotation: 45
                            color: server.on ? lp.hud.gold : lp.hud.glassBottom
                            border.width: 1
                            border.color: lp.hud.alpha(lp.hud.gold, server.on ? 1 : tabMa.containsMouse ? 0.9 : 0.45)
                            Behavior on width { NumberAnimation { duration: 140 } }
                            layer.enabled: server.on
                            layer.effect: MultiEffect {
                                shadowEnabled: true
                                shadowColor: lp.hud.gold
                                shadowBlur: 0.6
                                shadowHorizontalOffset: 0
                                shadowVerticalOffset: 0
                            }
                        }
                        Text {
                            anchors.centerIn: parent
                            text: lp.glyph(server.index)
                            color: server.on ? lp.hud.onGold : tabMa.containsMouse ? lp.hud.cyan : lp.hud.alpha(lp.hud.gold, 0.85)
                            font.family: lp.hud.serifFont
                            font.pixelSize: server.on ? 15 : 12
                            font.weight: Font.DemiBold
                        }
                        MouseArea {
                            id: tabMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { lp.tab = server.index; search.forceActiveFocus(); }
                            onContainsMouseChanged: {
                                if (containsMouse) lp.hoveredServer = server;
                                else if (lp.hoveredServer === server) lp.hoveredServer = null;
                            }
                        }
                    }
                }
            }
        }

        // Location line + status bars.
        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            Caps {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: "Root Town  //  " + (lp.searching ? "Search: " + search.text : lp.tabName)
                font.pixelSize: 15
            }
            Repeater {
                model: [["cpu", "CPU"], ["gpu", "GPU"], ["mem", "MEM"]]
                // Each stat: label + percent over an HP/SP style bar; hover for the real figures.
                Item {
                    id: stat
                    required property var modelDataData
                    readonly property real v: lp.hud[modelData[0]]
                    readonly property string detail: {
                        const H = lp.hud;
                        switch (modelData[0]) {
                        case "cpu": return H.cpuTemp.toFixed(0) + "°C  ·  " + (H.cpuFreq / 1000).toFixed(2) + " GHz";
                        case "gpu": return H.gpuTemp.toFixed(0) + "°C  ·  " + H.gpuPower.toFixed(0) + " W  ·  " + H.gpuFreq.toFixed(0) + " MHz";
                        case "mem": return H.bytes(H.memUsed) + " / " + H.bytes(H.memTotal) + " used";
                        }
                        return "";
                    }
                    implicitWidth: statCol.implicitWidth
                    implicitHeight: statCol.implicitHeight
                    z: statMa.containsMouse ? 60 : 0

                    ColumnLayout {
                        id: statCol
                        anchors.fill: parent
                        spacing: 2
                        RowLayout {
                            spacing: 4
                            Text {
                                text: stat.modelData[1]
                                color: lp.hud.inkDim
                                font.family: lp.hud.serifFont
                                font.pixelSize: 9
                                font.letterSpacing: 1
                            }
                            Text {
                                text: Math.round(stat.v) + "%"
                                color: lp.hud.ink
                                font.family: lp.hud.monoFont
                                font.pixelSize: 10
                            }
                        }
                        Rectangle {
                            Layout.preferredWidth: 46
                            Layout.preferredHeight: 4
                            color: lp.hud.alpha(lp.hud.glassBottom, 0.9)
                            border.width: 1
                            border.color: lp.hud.alpha(lp.hud.gold, 0.45)
                            Rectangle {
                                x: 1; y: 1
                                height: parent.height - 2
                                width: (parent.width - 2) * Math.min(1, stat.v / 100)
                                color: stat.v >= 85 ? lp.hud.crit : stat.v >= 65 ? lp.hud.warn : lp.hud.cyan
                                Behavior on width { NumberAnimation { duration: 400 } }
                            }
                        }
                    }
                    MouseArea {
                        id: statMa
                        anchors.fill: parent
                        hoverEnabled: true
                    }
                    // Detail plate, hanging under the bar.
                    Item {
                        anchors.right: parent.right
                        anchors.top: parent.bottom
                        anchors.topMargin: 6
                        width: detailText.implicitWidth + 24
                        height: detailText.implicitHeight + 14
                        opacity: statMa.containsMouse ? 1 : 0
                        visible: opacity > 0
                        Behavior on opacity { NumberAnimation { duration: 120 } }
                        HackFrame {
                            anchors.fill: parent
                            hud: lp.hud
                            radius: 4
                            stud: 4
                            trim: 0.9
                        }
                        Text {
                            id: detailText
                            anchors.centerIn: parent
                            text: stat.detail
                            color: lp.hud.ink
                            font.family: lp.hud.serifFont
                            font.italic: true
                            font.pixelSize: 11
                        }
                    }
                }
            }
        }

        // Areas.
        ListView {
            id: rows
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: lp.rowsData
            currentIndex: 0
            keyNavigationEnabled: false
            boundsBehavior: Flickable.StopAtBounds
            highlightMoveDuration: 90
            onCountChanged: if (currentIndex < 0 || currentIndex >= count) currentIndex = 0
            onModelChanged: currentIndex = 0

            delegate: Item {
                id: area
                required property int index
                required property var modelData
                readonly property bool on: ListView.isCurrentItem
                width: ListView.view.width
                height: 42

                // Selection: data-cyan wash fading right, framed by gold 『 』.
                Rectangle {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    visible: area.on || rowMa.containsMouse
                    opacity: area.on ? 1 : 0.5
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: lp.hud.alpha(lp.hud.cyan, 0.22) }
                        GradientStop { position: 0.7; color: lp.hud.alpha(lp.hud.cyan, 0.06) }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                }
                // 『 』 drawn to the row's full height (the font glyphs hang in their em box).
                component Bracket: Item {
                    property bool flip: false
                    width: 9
                    height: parent.height - 6
                    anchors.verticalCenter: parent.verticalCenter
                    visible: area.on
                    transform: Scale { origin.x: 4.5; xScale: flip ? -1 : 1 }
                    Rectangle { x: 0; width: 1.5; height: parent.height; color: lp.hud.gold }
                    Rectangle { x: 0; width: 8; height: 1.5; color: lp.hud.gold }
                    Rectangle { x: 0; y: parent.height - 1.5; width: 8; height: 1.5; color: lp.hud.gold }
                    Rectangle {
                        x: 4
                        y: parent.height * 0.22
                        width: 1
                        height: parent.height * 0.56
                        color: lp.hud.alpha(lp.hud.gold, 0.6)
                    }
                }
                Bracket { x: 4 }
                Bracket { x: parent.width - width - 4; flip: true }

                Text {
                    id: marker
                    x: 22
                    anchors.verticalCenter: parent.verticalCenter
                    text: area.on ? "◆" : "◇"
                    color: area.on ? lp.hud.cyan : lp.hud.alpha(lp.hud.gold, 0.6)
                    font.pixelSize: 10
                }
                Kirigami.Icon {
                    id: areaIcon
                    anchors.left: marker.right
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    width: 26
                    height: 26
                    source: area.modelData.icon
                }
                Text {
                    id: areaName
                    anchors.left: areaIcon.right
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: areaDesc.text ? -7 : 0
                    width: parent.width - x - 90
                    elide: Text.ElideRight
                    text: area.modelData.title
                    color: area.on ? lp.hud.ink : lp.hud.alpha(lp.hud.ink, 0.86)
                    font.family: lp.hud.labelFont
                    font.pixelSize: 14
                    font.weight: area.on ? Font.DemiBold : Font.Normal
                }
                Text {
                    id: areaDesc
                    anchors.left: areaName.left
                    anchors.top: areaName.bottom
                    width: areaName.width
                    elide: Text.ElideRight
                    text: area.modelData.desc
                    color: lp.hud.inkDim
                    font.family: lp.hud.serifFont
                    font.italic: true
                    font.pixelSize: 10
                }
                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 30
                    anchors.verticalCenter: parent.verticalCenter
                    visible: area.on
                    text: "WARP ⏎"
                    color: lp.hud.alpha(lp.hud.gold, 0.8)
                    font.family: lp.hud.serifFont
                    font.pixelSize: 9
                    font.letterSpacing: 2
                }
                MouseArea {
                    id: rowMa
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    onEntered: rows.currentIndex = area.index
                    onClicked: mouse => {
                        if (mouse.button === Qt.RightButton) lp.togglePin(area.modelData.storageId);
                        else lp.launch(area.modelData, mouse.modifiers & Qt.ShiftModifier);
                    }
                }
            }

            Caps {
                anchors.centerIn: parent
                visible: rows.count === 0 && !(lp.searching && lp.runnerModel.querying)
                text: lp.tab === 0 && !lp.searching ? "No pinned areas. Right-click any app to pin it." : "No such area"
                color: lp.hud.inkDim
                font.pixelSize: 13
            }
        }

        // Search.
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            Rectangle {
                anchors.fill: parent
                radius: 4
                color: lp.hud.alpha(lp.hud.glassBottom, 0.9)
                border.width: 1
                border.color: lp.hud.alpha(lp.hud.gold, search.activeFocus ? 0.8 : 0.35)
            }
            Text {
                id: prompt
                x: 12
                anchors.verticalCenter: parent.verticalCenter
                text: "›"
                color: lp.hud.gold
                font.family: lp.hud.serifFont
                font.pixelSize: 20
            }
            TextInput {
                id: search
                anchors.left: prompt.right
                anchors.leftMargin: 10
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                color: lp.hud.ink
                selectionColor: lp.hud.alpha(lp.hud.cyan, 0.4)
                font.family: lp.hud.labelFont
                font.pixelSize: 15
                focus: true
                clip: true
                onTextChanged: rows.currentIndex = 0

                Text {
                    visible: !search.text
                    text: "Enter a keyword…"
                    color: lp.hud.alpha(lp.hud.ink, 0.3)
                    font.family: lp.hud.serifFont
                    font.italic: true
                    font.pixelSize: 14
                }

                Keys.onDownPressed: rows.incrementCurrentIndex()
                Keys.onUpPressed: rows.decrementCurrentIndex()
                Keys.onLeftPressed: event => {
                    if (lp.searching) event.accepted = false;
                    else lp.step(-1);
                }
                Keys.onRightPressed: event => {
                    if (lp.searching) event.accepted = false;
                    else lp.step(1);
                }
                Keys.onTabPressed: if (!lp.searching) lp.step(1)
                Keys.onBacktabPressed: if (!lp.searching) lp.step(-1)
                Keys.onReturnPressed: event => lp.launch(lp.rowsData[rows.currentIndex], event.modifiers & Qt.ShiftModifier)
                Keys.onEnterPressed: event => lp.launch(lp.rowsData[rows.currentIndex], event.modifiers & Qt.ShiftModifier)
                Keys.onEscapePressed: {
                    if (search.text) search.text = "";
                    else lp.closeRequested();
                }
            }
        }

        // Player line + session menu.
        RowLayout {
            Layout.fillWidth: true
            spacing: 14
            Image {
                Layout.preferredWidth: 22
                Layout.preferredHeight: 22
                visible: status === Image.Ready
                source: lp.hud.avatar
                sourceSize: Qt.size(44, 44)
                fillMode: Image.PreserveAspectCrop
            }
            Caps {
                text: lp.hud.user || "player"
                color: lp.hud.ink
                font.pixelSize: 14
            }
            Text {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: "@" + (lp.hud.hostname || "host") + "  ·  up " + lp.hud.uptimeLong(lp.hud.uptime).toLowerCase()
                color: lp.hud.inkDim
                font.family: lp.hud.serifFont
                font.pixelSize: 10
            }
            component Session: Caps {
                id: sess
                property string cmd
                property int holdMs: 0
                property real charge: 0
                font.pixelSize: 11
                color: sessMa.containsMouse ? lp.hud.cyan : lp.hud.alpha(lp.hud.gold, 0.85)
                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.bottom
                    width: parent.width * sess.charge
                    height: 1
                    color: lp.hud.crit
                }
                NumberAnimation {
                    id: holdAnim
                    target: sess
                    property: "charge"
                    to: 1
                    duration: sess.holdMs
                    onFinished: if (sess.charge >= 0.999) { sess.charge = 0; lp.command(sess.cmd, false); }
                }
                MouseArea {
                    id: sessMa
                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPressed: if (sess.holdMs > 0) { sess.charge = 0; holdAnim.restart(); }
                    onReleased: if (sess.holdMs > 0 && holdAnim.running) { holdAnim.stop(); sess.charge = 0; }
                    onClicked: if (sess.holdMs === 0) lp.command(sess.cmd, false)
                }
            }
            Session { text: "Lock"; cmd: "loginctl lock-session" }
            Session { text: "Sleep"; cmd: "systemctl suspend"; holdMs: 600 }
            Session { text: "Log out"; cmd: "qdbus6 org.kde.Shutdown /Shutdown logout"; holdMs: 900 }
            Session { text: "Reboot"; cmd: "qdbus6 org.kde.Shutdown /Shutdown logoutAndReboot"; holdMs: 900 }
            Session { text: "Halt"; cmd: "qdbus6 org.kde.Shutdown /Shutdown logoutAndShutdown"; holdMs: 900 }
        }
    }

    // Server tooltip: a small plate that slides out under the hovered glyph.
    Item {
        id: tip
        z: 100
        readonly property Item at: lp.hoveredServer
        property int shown: -1
        visible: opacity > 0
        opacity: at ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 140 } }
        width: Math.max(150, Math.max(tipName.implicitWidth, tipSub.implicitWidth) + 74)
        height: 54
        // Where the hovered glyph's center is, and where the plate settles. The notch is
        // placed from these targets (mapToItem results are not live bindings).
        property real glyphX: 0
        property real targetX: 0
        function place() {
            if (!at) return;
            const c = at.mapToItem(lp, at.width / 2, at.height);
            glyphX = c.x;
            targetX = Math.max(14, Math.min(lp.width - width - 14, c.x - width / 2));
            y = c.y + 6;
        }
        onAtChanged: if (at) {
            shown = at.index;
            place();
        }
        // The text (and so the width) changes right after `shown`; clamp again.
        onWidthChanged: place()
        x: targetX
        Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

        HackFrame {
            anchors.fill: parent
            hud: lp.hud
            stud: 5
            trim: 0.9
        }
        // Pointer notch toward the glyph.
        Rectangle {
            width: 8
            height: 8
            rotation: 45
            x: tip.glyphX - tip.targetX - 4
            y: -4
            color: lp.hud.glassTop
            border.width: 1
            border.color: lp.hud.alpha(lp.hud.gold, 0.9)
        }
        Text {
            id: tipGlyph
            x: 14
            anchors.verticalCenter: parent.verticalCenter
            text: lp.glyph(Math.max(0, tip.shown))
            color: lp.hud.gold
            font.family: lp.hud.serifFont
            font.pixelSize: 26
        }
        Column {
            anchors.left: tipGlyph.right
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1
            Text {
                id: tipName
                text: lp.tabTitle(Math.max(0, tip.shown))
                color: lp.hud.ink
                font.family: lp.hud.serifFont
                font.capitalization: Font.SmallCaps
                font.letterSpacing: 2
                font.pixelSize: 14
            }
            Text {
                id: tipSub
                readonly property int n: lp.tabSize(Math.max(0, tip.shown))
                text: n + (n === 1 ? " area" : " areas") + "  ·  ←/→ to travel"
                color: lp.hud.inkDim
                font.family: lp.hud.serifFont
                font.italic: true
                font.pixelSize: 10
            }
        }
    }
}
