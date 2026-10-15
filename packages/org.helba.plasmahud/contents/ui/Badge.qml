import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

// Panel badge: chamfered plate with live readouts and LED segment meters.
Item {
    id: badge

    required property QtObject hud
    property bool vertical: false
    // false inside an island: no plate of its own, no inset, no sweep.
    property bool plated: true
    signal activated

    readonly property var keys: {
        const c = hud.cfg, k = [];
        if (c.badgeCpu) k.push("cpu");
        if (c.badgeGpu) k.push("gpu");
        if (c.badgeMem) k.push("mem");
        if (c.badgeTemp) k.push("tmp");
        if (c.badgeNet) k.push("net");
        if (c.badgeUptime) k.push("up");
        if (k.length === 0) k.push("cpu");
        return k;
    }

    readonly property real thick: vertical ? width : height
    readonly property real inset: !plated ? 0 : thick >= 30 ? 4 : 2
    readonly property int vSize: Math.round(Math.max(10, Math.min((thick - inset * 2) * 0.46, 18)))
    readonly property int lSize: Math.max(7, Math.round(vSize * 0.58))
    readonly property real padX: plated ? Math.round(vSize * 0.8) : 0
    readonly property bool hot: ma.containsMouse || hud.open

    readonly property real naturalWidth: row.implicitWidth + padX * 2
    readonly property real naturalHeight: column.implicitHeight + 16

    Layout.minimumWidth: vertical ? 0 : naturalWidth
    Layout.preferredWidth: vertical ? -1 : naturalWidth
    Layout.maximumWidth: vertical ? Number.POSITIVE_INFINITY : naturalWidth
    Layout.minimumHeight: vertical ? naturalHeight : 0
    Layout.preferredHeight: vertical ? naturalHeight : -1
    Layout.maximumHeight: vertical ? naturalHeight : Number.POSITIVE_INFINITY

    function textOf(k) {
        const h = hud;
        switch (k) {
        case "cpu": return h.pad3(h.cpu);
        case "gpu": return h.pad3(h.gpu);
        case "mem": return h.pad3(h.mem);
        case "tmp": return Math.round(h.cpuTemp) + "°" + (vertical ? "" : "/" + Math.round(h.gpuTemp) + "°");
        case "net": return vertical ? h.rateShort(h.netDown) : "↓" + h.rateShort(h.netDown) + " ↑" + h.rateShort(h.netUp);
        case "up": return h.uptimeShort(h.uptime);
        }
        return "";
    }
    function templateOf(k) {
        switch (k) {
        case "tmp": return vertical ? "00°" : "00°/00°";
        case "net": return vertical ? "00.0K" : "↓00.0K ↑00.0K";
        case "up": return "00D00H";
        }
        return "000";
    }
    function levelOf(k) {
        const h = hud;
        switch (k) {
        case "cpu": return h.cpu;
        case "gpu": return h.gpu;
        case "mem": return h.mem;
        case "tmp": return Math.max(h.cpuTemp, h.gpuTemp);
        }
        return -1;
    }
    function colorOf(k) {
        return k === "tmp" ? hud.tempLevel(levelOf(k)) : hud.level(levelOf(k));
    }

    // Plate.
    HackFrame {
        id: plate
        hud: badge.hud
        visible: badge.plated
        x: badge.vertical ? badge.inset : 0
        y: badge.vertical ? 0 : badge.inset
        width: parent.width - (badge.vertical ? badge.inset * 2 : 0)
        height: parent.height - (badge.vertical ? 0 : badge.inset * 2)
        radius: 5
        stud: 5
        trim: badge.hot ? 0.95 : 0.6
    }

    // Occasional light sweep across the plate.
    Item {
        anchors.fill: plate
        clip: true
        visible: badge.plated
        Rectangle {
            id: sweep
            width: 26
            height: parent.height
            x: -width
            opacity: 0.0
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.5; color: badge.hud.alpha(badge.hud.accent, 0.35) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }
        SequentialAnimation {
            running: badge.visible && badge.hud.cfg.glitch
            loops: Animation.Infinite
            PauseAnimation { duration: 7000 }
            PropertyAction { target: sweep; property: "opacity"; value: 1 }
            NumberAnimation { target: sweep; property: "x"; from: -26; to: plate.width; duration: 700; easing.type: Easing.InOutQuad }
            PropertyAction { target: sweep; property: "opacity"; value: 0 }
        }
    }

    component Led: Rectangle {
        width: Math.max(4, Math.round(badge.vSize * 0.32))
        height: width
        rotation: 45
        color: badge.hud.open ? badge.hud.accent : badge.hud.accent2
        SequentialAnimation on opacity {
            running: !badge.hud.open && badge.visible
            loops: Animation.Infinite
            NumberAnimation { to: 0.25; duration: 900; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1.0; duration: 900; easing.type: Easing.InOutSine }
        }
    }

    component Segments: Row {
        id: seg
        property real level: 0
        property color tone: badge.hud.accent
        property real span: 30
        spacing: 1
        Repeater {
            model: 10
            Rectangle {
                required property int index
                width: (seg.span - 9) / 10
                height: 2
                color: index < Math.round(seg.level / 10)
                    ? seg.tone : badge.hud.alpha(badge.hud.accent, 0.16)
            }
        }
    }

    component Metric: Item {
        id: m
        required property string modelData
        required property int index
        readonly property real lvl: badge.levelOf(modelData)
        readonly property color tone: badge.colorOf(modelData)
        implicitWidth: label.implicitWidth + 4 + valueBox.width
        implicitHeight: valueBox.height

        TextMetrics {
            id: tm
            font: value.font
            text: badge.templateOf(m.modelData)
        }
        Text {
            id: label
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: m.lvl >= 0 ? -1 : 0
            text: m.modelData.toUpperCase()
            color: badge.hud.alpha(badge.hud.text, 0.55)
            font.family: badge.hud.labelFont
            font.pixelSize: badge.lSize
            font.weight: Font.DemiBold
            font.letterSpacing: 1.5
        }
        Item {
            id: valueBox
            x: label.implicitWidth + 4
            width: Math.ceil(tm.advanceWidth)
            height: value.implicitHeight + (m.lvl >= 0 ? 4 : 0)
            anchors.verticalCenter: parent.verticalCenter
            Text {
                id: value
                anchors.right: parent.right
                text: badge.textOf(m.modelData)
                color: badge.hud.text
                font.family: badge.hud.monoFont
                font.pixelSize: badge.vSize
                font.weight: Font.Bold
                layer.enabled: badge.hud.glow > 0
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: m.tone
                    shadowBlur: 0.45
                    shadowOpacity: badge.hud.glow
                    shadowHorizontalOffset: 0
                    shadowVerticalOffset: 0
                }
            }
            Segments {
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                visible: m.lvl >= 0
                span: parent.width
                level: m.lvl
                tone: m.tone
            }
        }
    }

    // Horizontal layout.
    Row {
        id: row
        visible: !badge.vertical
        anchors.verticalCenter: parent.verticalCenter
        x: badge.padX
        spacing: Math.round(badge.vSize * 0.6)

        Led { anchors.verticalCenter: parent.verticalCenter }
        Repeater {
            model: badge.keys
            Row {
                required property string modelData
                required property int index
                anchors.verticalCenter: parent.verticalCenter
                spacing: Math.round(badge.vSize * 0.6)
                // Slanted divider.
                Rectangle {
                    visible: index > 0
                    anchors.verticalCenter: parent.verticalCenter
                    width: 1
                    height: badge.vSize * 1.1
                    rotation: 18
                    color: badge.hud.alpha(badge.hud.accent, 0.35)
                }
                Metric {
                    modelData: parent.modelData
                    index: parent.index
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }

    // Vertical layout: label over value, stacked.
    Column {
        id: column
        visible: badge.vertical
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        Led { anchors.horizontalCenter: parent.horizontalCenter }
        Repeater {
            model: badge.keys
            Column {
                required property string modelData
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 1
                readonly property real lvl: badge.levelOf(modelData)
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: parent.modelData.toUpperCase()
                    color: badge.hud.alpha(badge.hud.text, 0.55)
                    font.family: badge.hud.labelFont
                    font.pixelSize: badge.lSize
                    font.letterSpacing: 1
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: badge.textOf(parent.modelData)
                    color: badge.hud.text
                    font.family: badge.hud.monoFont
                    font.pixelSize: Math.min(badge.vSize, badge.width * 0.3)
                    font.weight: Font.Bold
                }
                Segments {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: parent.lvl >= 0
                    span: badge.width * 0.6
                    level: parent.lvl
                    tone: badge.colorOf(parent.modelData)
                }
            }
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: badge.activated()
    }
}
