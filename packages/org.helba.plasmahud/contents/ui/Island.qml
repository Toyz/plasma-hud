import QtQuick
import QtQuick.Effects

// A floating plate that hugs its content. With wrapPrevious the plate also extends
// under the applet just before this one in the panel (the stock system tray), drawn
// in the panel layout's parent at z -1 so it sits behind that applet.
Item {
    id: isl

    required property QtObject hud
    property bool wrapPrevious: false
    readonly property real padX: Math.round(height * 0.42)
    readonly property real gap: Math.round(height * 0.4)
    default property alias content: row.data

    implicitWidth: row.implicitWidth + padX * 2
    implicitHeight: 30

    component Plate: HackFrame {
        hud: isl.hud
        radius: 5
        stud: 5
        trim: 0.7
    }

    Plate {
        anchors.fill: parent
        visible: !external.active
    }

    Row {
        id: row
        x: isl.padX
        anchors.verticalCenter: parent.verticalCenter
        spacing: isl.gap
    }

    // ------------------------------------------------------------ wrap the tray

    QtObject {
        id: external
        property bool active: false
        property Item plate: null
        property Item mine: null      // our AppletContainer
        property Item layer: null     // the panel layout's parent, where the plate lives
    }

    function containerOf(item) {
        for (let p = item; p && p.parent; p = p.parent) {
            if (String(p.parent).indexOf("GridLayout") >= 0 || String(p.parent).indexOf("QQuickGridLayout") >= 0)
                return p;
        }
        return null;
    }

    function previousContainer() {
        const mine = external.mine;
        let best = null;
        const kids = mine.parent.children;
        for (let i = 0; i < kids.length; i++) {
            const k = kids[i];
            if (k === mine || !k.visible || k.width <= 1 || String(k).indexOf("AppletContainer") < 0) continue;
            if (k.x < mine.x && (!best || k.x > best.x)) best = k;
        }
        return best;
    }

    function syncExternal() {
        if (!external.active) return;
        const prev = previousContainer();
        const p = external.plate;
        if (!prev) { p.visible = false; return; }
        const a = prev.mapToItem(external.layer, 0, 0);
        const b = isl.mapToItem(external.layer, isl.width, isl.height);
        const top = isl.mapToItem(external.layer, 0, 0);
        p.x = Math.round(a.x - isl.padX);
        p.y = Math.round(top.y);
        p.width = Math.round(b.x - p.x);
        p.height = Math.round(b.y - top.y);
        p.visible = true;
    }

    Component {
        id: externalPlate
        Plate { z: -1 }
    }

    function attachExternal() {
        if (!wrapPrevious || external.active) return;
        const mine = containerOf(isl);
        if (!mine || !mine.parent || !mine.parent.parent) return;
        external.mine = mine;
        external.layer = mine.parent.parent;
        external.plate = externalPlate.createObject(external.layer);
        external.active = true;
        syncExternal();
    }

    Timer {
        // The panel lays applets out after we exist, and tray icons come and go:
        // keep the outer plate glued to them.
        interval: external.active ? 400 : 1500
        running: isl.wrapPrevious && isl.visible
        repeat: true
        onTriggered: external.active ? isl.syncExternal() : isl.attachExternal()
    }

    // ------------------------------------------------------------ tint app tray icons

    // Apps like Discord, Docker or Claude hand the tray a picture instead of an icon
    // name, so no icon theme reaches them. Tint just those (the tray's StatusNotifier
    // delegates, not Plasma's own applets) into gold silhouettes. Leans on how the
    // stock tray builds its delegates; if that ever changes, nothing gets tinted.
    Component {
        id: trayTint
        MultiEffect {
            colorization: 1.0
            colorizationColor: isl.hud.gold
            brightness: 0.12
        }
    }
    function tintTray() {
        try {
            const tray = previousContainer();
            if (!tray) return;
            let added = 0;
            const visit = (it, depth) => {
                if (!it || depth > 12) return;
                let sni = false;
                try { sni = it.model && it.model.itemType === "StatusNotifier" && String(it).indexOf("StatusNotifierItem") === 0; } catch (e) {}
                if (sni) {
                    const icon = findIcon(it, 0);
                    if (icon && !icon.layer.enabled) {
                        icon.layer.enabled = true;
                        icon.layer.effect = trayTint;
                        added++;
                    }
                    return;
                }
                for (let i = 0; i < it.children.length; i++) visit(it.children[i], depth + 1);
            };
            visit(tray, 0);
            if (added) console.warn("plasmahud: tinted", added, "app tray icons");
        } catch (e) {
            console.warn("plasmahud: tray tint skipped:", e);
        }
    }
    function findIcon(it, depth) {
        if (!it || depth > 4) return null;
        if (String(it).indexOf("Icon") === 0) return it;
        for (let i = 0; i < it.children.length; i++) {
            const f = findIcon(it.children[i], depth + 1);
            if (f) return f;
        }
        return null;
    }
    Timer {
        // Tray icons come and go; tint newcomers.
        interval: 2000
        running: isl.wrapPrevious && isl.visible && external.active
        repeat: true
        triggeredOnStart: true
        onTriggered: isl.tintTray()
    }

    Component.onDestruction: if (external.plate) external.plate.destroy()
}
