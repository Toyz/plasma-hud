import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import org.kde.kirigami as Kirigami
import "../../../org.helba.plasmahud/contents/ui"

// The Chaos Gate. Type keywords; areas (workspaces), windows and commands answer.
// Enter warps: the ring blows open, a flash hides the switch, the gate fades.
// Up/Down choose, Tab cycles the filter, Shift+Enter opens a new app instance,
// Esc closes. Destructive commands ask for a second Enter.
FocusScope {
    id: gp

    required property QtObject hud
    property var areas: []      // [{ index, id, name, glyph, current, windows }]
    property var windows: []    // [{ row, title, app, icon, area }]
    property var commands: []   // [{ key, glyph, name, hint, words, danger }]
    signal warpTo(int index)
    signal focusWindow(int row)
    signal command(string key, bool shift)
    signal removeArea(int index)
    property int armedArea: -1     // an area waiting for its second Shift+Del
    signal closeRequested

    readonly property var filters: ["All", "Areas", "Windows", "Commands"]
    property int filter: 0
    property int current: 0
    property string armed: ""      // a destructive command waiting for its second Enter
    property bool warping: false

    function setQuery(q) { input.text = q; }

    function reset() {
        input.text = "";
        filter = 0;
        current = 0;
        armed = "";
        armedArea = -1;
        warping = false;
        ring.scale = 1;
        ring.opacity = 0.9;
        flash.opacity = 0;
        veil.opacity = 0;
        intro.restart();
        input.forceActiveFocus();
    }

    readonly property var results: {
        const q = input.text.toLowerCase().trim().split(/\s+/).filter(t => t.length);
        const hit = text => q.every(t => text.toLowerCase().indexOf(t) >= 0);
        const out = [];
        if (filter === 0 || filter === 1)
            for (const a of areas) {
                const sub = a.current ? "you are here" : a.windows + (a.windows === 1 ? " window" : " windows");
                // The badge already shows the server glyph; drop it from the title.
                if (hit(a.name + " area workspace " + (a.index + 1)))
                    out.push({ kind: "Area", title: a.name.replace(/^\S\s+/, a.name.charAt(0) === a.glyph ? "" : a.name.charAt(0) + " "), sub: sub, glyph: a.glyph, ref: a.index, current: a.current });
            }
        if (filter === 0 || filter === 2)
            for (const w of windows)
                if ((q.length || filter === 2) && hit(w.title + " " + w.app + " window"))
                    out.push({ kind: "Window", title: w.title, sub: w.app + (w.area ? "  ·  " + w.area : ""), icon: w.icon, ref: w.row });
        if (filter === 0 || filter === 3)
            for (const c of commands)
                if (hit(c.name + " " + c.words + " command"))
                    out.push({ kind: "Command", title: c.name, sub: c.hint, glyph: c.glyph, ref: c.key, danger: !!c.danger });
        return out.slice(0, 9);
    }
    onResultsChanged: if (current >= results.length) current = 0

    function choose(shift) {
        const r = results[current];
        if (!r || warping) return;
        if (r.kind === "Command" && r.danger && armed !== r.ref) {
            armed = r.ref;
            return;
        }
        armed = "";
        warp(r, shift);
    }

    // Warp: open the ring, flash at the peak (do the work under it), then fade out.
    function warp(r, shift) {
        warping = true;
        warpAnim.item = r;
        warpAnim.shift = !!shift;
        warpAnim.restart();
    }
    // The gate steps aside fast; the shared warp (all screens) takes it from there.
    SequentialAnimation {
        id: warpAnim
        property var item: null
        property bool shift: false
        ParallelAnimation {
            NumberAnimation { target: content; property: "opacity"; to: 0; duration: 120 }
            NumberAnimation { target: ring; property: "scale"; to: 1.25; duration: 140; easing.type: Easing.InQuad }
            NumberAnimation { target: veil; property: "opacity"; to: 0; duration: 140 }
            NumberAnimation { target: ring; property: "opacity"; to: 0; duration: 140 }
        }
        ScriptAction {
            script: {
                gp.closeRequested();
                const r = warpAnim.item;
                if (r.kind === "Area") gp.warpTo(r.ref);
                else if (r.kind === "Window") gp.focusWindow(r.ref);
                else gp.command(r.ref, warpAnim.shift);
            }
        }
    }

    SequentialAnimation {
        id: intro
        ParallelAnimation {
            NumberAnimation { target: veil; property: "opacity"; from: 0; to: 1; duration: 180 }
            NumberAnimation { target: content; property: "opacity"; from: 0; to: 1; duration: 220 }
            NumberAnimation { target: ring; property: "scale"; from: 0.6; to: 1; duration: 320; easing.type: Easing.OutBack }
        }
    }

    // ------------------------------------------------------------ backdrop

    Rectangle {
        id: veil
        anchors.fill: parent
        color: gp.hud.alpha(gp.hud.glassBottom, 0.86)
        MouseArea {
            anchors.fill: parent
            onClicked: gp.closeRequested()
        }
    }

    // The gate ring.
    Item {
        id: ring
        readonly property real d: Math.min(gp.width, gp.height) * 0.7
        width: d
        height: d
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -gp.height * 0.04
        opacity: 0.9

        // Outer rule and server glyphs, turning slowly.
        Item {
            anchors.fill: parent
            RotationAnimation on rotation {
                running: gp.visible
                from: 0; to: 360
                duration: gp.warping ? 2400 : 120000
                loops: Animation.Infinite
            }
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: "transparent"
                border.width: 1.5
                border.color: gp.hud.alpha(gp.hud.gold, 0.35)
            }
            Rectangle {
                anchors.fill: parent
                anchors.margins: 46
                radius: width / 2
                color: "transparent"
                border.width: 1
                border.color: gp.hud.alpha(gp.hud.gold, 0.18)
            }
            Repeater {
                model: 24
                Text {
                    required property int index
                    readonly property real a: index / 24 * Math.PI * 2
                    x: ring.d / 2 + Math.cos(a) * (ring.d / 2 - 23) - width / 2
                    y: ring.d / 2 + Math.sin(a) * (ring.d / 2 - 23) - height / 2
                    rotation: index / 24 * 360 + 90
                    text: "ΔΘΛΣΩΦΨΞΠΓΒΖ".charAt(index % 12)
                    color: gp.hud.alpha(gp.hud.gold, index % 3 === 0 ? 0.75 : 0.35)
                    font.family: gp.hud.serifFont
                    font.pixelSize: 18
                }
            }
            Repeater {
                model: 3
                Rectangle {
                    required property int index
                    readonly property real a: index / 3 * Math.PI * 2
                    width: 10
                    height: 10
                    rotation: 45
                    color: gp.hud.gold
                    x: ring.d / 2 + Math.cos(a) * ring.d / 2 - 5
                    y: ring.d / 2 + Math.sin(a) * ring.d / 2 - 5
                }
            }
        }
        // Inner data ring, counter-rotating.
        Shape {
            anchors.fill: parent
            anchors.margins: ring.d * 0.16
            preferredRendererType: Shape.CurveRenderer
            RotationAnimation on rotation {
                running: gp.visible
                from: 360; to: 0
                duration: gp.warping ? 1600 : 80000
                loops: Animation.Infinite
            }
            ShapePath {
                fillColor: "transparent"
                strokeColor: gp.hud.alpha(gp.hud.cyan, 0.3)
                strokeWidth: 1
                strokeStyle: ShapePath.DashLine
                dashPattern: [2, 6]
                PathAngleArc {
                    centerX: ring.d * 0.34; centerY: ring.d * 0.34
                    radiusX: ring.d * 0.34; radiusY: ring.d * 0.34
                    startAngle: 0; sweepAngle: 360
                }
            }
        }
    }

    // ------------------------------------------------------------ palette

    ColumnLayout {
        id: content
        width: Math.min(680, gp.width - 80)
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.max(40, ring.y + ring.height * 0.2)
        spacing: 14

        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 0
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "Chaos Gate"
                color: gp.hud.gold
                font.family: gp.hud.serifFont
                font.capitalization: Font.SmallCaps
                font.letterSpacing: 6
                font.pixelSize: 34
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "Enter keywords to warp"
                color: gp.hud.alpha(gp.hud.ink, 0.75)
                font.family: gp.hud.serifFont
                font.italic: true
                font.pixelSize: 15
            }
        }

        // Keyword field.
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 54
            HackFrame {
                anchors.fill: parent
                hud: gp.hud
                radius: 6
                stud: 6
            }
            Text {
                id: prompt
                x: 20
                anchors.verticalCenter: parent.verticalCenter
                text: "›"
                color: gp.hud.gold
                font.family: gp.hud.serifFont
                font.pixelSize: 26
            }
            TextInput {
                id: input
                anchors.left: prompt.right
                anchors.leftMargin: 14
                anchors.right: parent.right
                anchors.rightMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                color: gp.hud.ink
                selectionColor: gp.hud.alpha(gp.hud.cyan, 0.4)
                font.family: gp.hud.serifFont
                font.pixelSize: 20
                focus: true
                clip: true
                onTextChanged: { gp.current = 0; gp.armed = ""; gp.armedArea = -1; }
                Text {
                    visible: !input.text
                    text: "hidden forbidden holy ground…"
                    color: gp.hud.alpha(gp.hud.ink, 0.25)
                    font: input.font
                }
                Keys.onDownPressed: { gp.armedArea = -1; gp.current = Math.min(gp.results.length - 1, gp.current + 1); }
                Keys.onUpPressed: { gp.armedArea = -1; gp.current = Math.max(0, gp.current - 1); }
                Keys.onTabPressed: gp.filter = (gp.filter + 1) % gp.filters.length
                Keys.onBacktabPressed: gp.filter = (gp.filter + gp.filters.length - 1) % gp.filters.length
                Keys.onReturnPressed: event => gp.choose(event.modifiers & Qt.ShiftModifier)
                Keys.onEnterPressed: event => gp.choose(event.modifiers & Qt.ShiftModifier)
                Keys.onEscapePressed: {
                    if (input.text) input.text = "";
                    else gp.closeRequested();
                }
                Keys.onPressed: event => {
                    // Shift+Del on an area: arm, then close it on the second press.
                    if (event.key === Qt.Key_Delete && (event.modifiers & Qt.ShiftModifier)) {
                        const r = gp.results[gp.current];
                        if (r && r.kind === "Area" && gp.areas.length > 1) {
                            if (gp.armedArea === r.ref) {
                                gp.armedArea = -1;
                                gp.removeArea(r.ref);
                            } else {
                                gp.armedArea = r.ref;
                            }
                        }
                        event.accepted = true;
                        return;
                    }
                    // Empty field: 1-9 warp straight to that area.
                    if (!input.text && event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
                        const i = event.key - Qt.Key_1;
                        if (i < gp.areas.length) {
                            gp.warp({ kind: "Area", ref: i }, false);
                            event.accepted = true;
                        }
                    }
                }
            }
        }

        // Filter tabs.
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 18
            Repeater {
                model: gp.filters
                Text {
                    required property int index
                    required property string modelData
                    text: (index === gp.filter ? "◆ " : "◇ ") + modelData
                    color: index === gp.filter ? gp.hud.gold : gp.hud.inkDim
                    font.family: gp.hud.serifFont
                    font.capitalization: Font.SmallCaps
                    font.letterSpacing: 1.5
                    font.pixelSize: 13
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { gp.filter = parent.index; input.forceActiveFocus(); }
                    }
                }
            }
        }

        // Results.
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.max(1, gp.results.length) * 48 + 20
            visible: gp.results.length > 0 || input.text.length > 0
            HackFrame {
                anchors.fill: parent
                hud: gp.hud
                radius: 6
                stud: 6
            }
            Text {
                anchors.centerIn: parent
                visible: gp.results.length === 0
                text: "No gate answers to that"
                color: gp.hud.inkDim
                font.family: gp.hud.serifFont
                font.italic: true
                font.pixelSize: 13
            }
            Column {
                x: 10
                y: 10
                width: parent.width - 20
                Repeater {
                    model: gp.results
                    Item {
                        id: row
                        required property int index
                        required property var modelData
                        readonly property bool on: index === gp.current
                        readonly property bool armedHere: (gp.armed !== "" && gp.armed === modelData.ref)
                            || (modelData.kind === "Area" && gp.armedArea === modelData.ref)
                        width: parent.width
                        height: 48

                        Rectangle {
                            anchors.fill: parent
                            anchors.leftMargin: 6
                            anchors.rightMargin: 6
                            visible: row.on || rowMa.containsMouse
                            opacity: row.on ? 1 : 0.5
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.0; color: gp.hud.alpha(row.armedHere ? gp.hud.crit : gp.hud.cyan, 0.24) }
                                GradientStop { position: 1.0; color: "transparent" }
                            }
                        }
                        component Bracket: Item {
                            property bool flip: false
                            width: 9
                            height: parent.height - 8
                            anchors.verticalCenter: parent.verticalCenter
                            visible: row.on
                            transform: Scale { origin.x: 4.5; xScale: flip ? -1 : 1 }
                            Rectangle { width: 1.5; height: parent.height; color: gp.hud.gold }
                            Rectangle { width: 8; height: 1.5; color: gp.hud.gold }
                            Rectangle { y: parent.height - 1.5; width: 8; height: 1.5; color: gp.hud.gold }
                        }
                        Bracket { x: 2 }
                        Bracket { x: parent.width - width - 2; flip: true }

                        // Glyph or icon.
                        Item {
                            id: badge
                            x: 22
                            width: 30
                            height: 30
                            anchors.verticalCenter: parent.verticalCenter
                            Rectangle {
                                anchors.centerIn: parent
                                visible: !row.modelData.icon
                                width: 22
                                height: 22
                                rotation: 45
                                color: row.modelData.current ? gp.hud.gold : "transparent"
                                border.width: 1
                                border.color: gp.hud.alpha(row.modelData.danger ? gp.hud.crit : gp.hud.gold, 0.8)
                            }
                            Text {
                                anchors.centerIn: parent
                                visible: !row.modelData.icon
                                text: row.modelData.glyph || "◇"
                                color: row.modelData.current ? gp.hud.onGold : row.modelData.danger ? gp.hud.crit : gp.hud.gold
                                font.family: gp.hud.serifFont
                                font.pixelSize: 14
                            }
                            Kirigami.Icon {
                                anchors.fill: parent
                                visible: !!row.modelData.icon
                                source: row.modelData.icon || ""
                            }
                        }
                        Column {
                            anchors.left: badge.right
                            anchors.leftMargin: 14
                            anchors.right: tag.left
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            Text {
                                width: parent.width
                                elide: Text.ElideRight
                                text: row.modelData.title
                                color: row.on ? gp.hud.ink : gp.hud.alpha(gp.hud.ink, 0.88)
                                font.family: row.modelData.kind === "Window" ? gp.hud.labelFont : gp.hud.serifFont
                                font.pixelSize: 16
                            }
                            Text {
                                width: parent.width
                                elide: Text.ElideRight
                                text: !row.armedHere ? row.modelData.sub
                                    : row.modelData.kind === "Area" ? "Shift+Del again to close this area (its windows move over)"
                                    : "press Enter again to confirm"
                                color: row.armedHere ? gp.hud.crit : gp.hud.inkDim
                                font.family: gp.hud.serifFont
                                font.italic: true
                                font.pixelSize: 11
                            }
                        }
                        Text {
                            id: tag
                            anchors.right: parent.right
                            anchors.rightMargin: 24
                            anchors.verticalCenter: parent.verticalCenter
                            text: row.on ? (row.modelData.kind === "Area" ? "Warp ⏎" : row.modelData.kind === "Window" ? "Jump ⏎" : "Run ⏎") : row.modelData.kind
                            color: row.on ? gp.hud.gold : gp.hud.alpha(gp.hud.inkDim, 0.8)
                            font.family: gp.hud.serifFont
                            font.capitalization: Font.SmallCaps
                            font.letterSpacing: 1.5
                            font.pixelSize: 11
                        }
                        MouseArea {
                            id: rowMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: gp.current = row.index
                            onClicked: mouse => gp.choose(mouse.modifiers & Qt.ShiftModifier)
                        }
                    }
                }
            }
        }

        // Key help: gold keycaps with their meaning beside them.
        ColumnLayout {
            // Two centered rows: one row ran wider than the column and pushed it off the ring.
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 4
            spacing: 8
            Repeater {
                model: [
                    [["↑ ↓", "choose"], ["⏎", "warp"], ["⇧ ⏎", "new instance"], ["1–9", "jump to area"]],
                    [["⇧ Del", "close area"], ["Tab", "filter"], ["Esc", "close"]]
                ]
                RowLayout {
                    id: helpRow
                    required property var modelData
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 18
                    Repeater {
                        model: helpRow.modelData
                        Row {
                            required property var modelData
                            spacing: 7
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.max(26, keyText.implicitWidth + 14)
                                height: 22
                                radius: 4
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: gp.hud.glassTop }
                                    GradientStop { position: 1.0; color: gp.hud.glassBottom }
                                }
                                border.width: 1
                                border.color: gp.hud.alpha(gp.hud.gold, 0.75)
                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: 2
                                    width: parent.width - 8
                                    height: 1
                                    color: gp.hud.alpha(gp.hud.gold, 0.35)
                                }
                                Text {
                                    id: keyText
                                    anchors.centerIn: parent
                                    anchors.verticalCenterOffset: -1
                                    text: modelData[0]
                                    color: gp.hud.gold
                                    font.family: gp.hud.serifFont
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                }
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData[1]
                                color: gp.hud.alpha(gp.hud.ink, 0.85)
                                font.family: gp.hud.serifFont
                                font.capitalization: Font.SmallCaps
                                font.letterSpacing: 1
                                font.pixelSize: 13
                            }
                        }
                    }
                }
            }
        }
    }

    // Warp flash.
    Rectangle {
        id: flash
        anchors.fill: parent
        opacity: 0
        gradient: Gradient {
            GradientStop { position: 0.0; color: gp.hud.cyan }
            GradientStop { position: 0.5; color: "#ffffff" }
            GradientStop { position: 1.0; color: gp.hud.gold }
        }
    }
}
