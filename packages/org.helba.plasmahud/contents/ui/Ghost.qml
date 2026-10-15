import QtQuick

// Ghost panel: hide the panel view's own background so only HUD plates show.
//
// The panel view draws its background with FrameSvgItems (panel-background,
// solid/panel-background) and derives its window mask from them. Turning the
// background off with NoBackground empties that mask and blanks the whole panel, so
// instead we keep the SVGs and hold their opacity at 0. Set the panel to opaque mode
// as well (hudctl does) so KWin does not blur a strip behind it.
Item {
    id: ghost

    property Item anchor: null
    property bool active: false
    property int layers: 0

    function panelRoot() {
        // Panel.qml's root is the only ancestor carrying panelMask.
        for (let p = anchor; p; p = p.parent) {
            if (p.panelMask !== undefined && p.containment !== undefined)
                return p;
        }
        return null;
    }

    function attach() {
        if (layers > 0 || !anchor) return;
        const root = panelRoot();
        if (!root) {
            console.warn("plasmahud: ghost panel: panel view not found; leaving the background alone");
            return;
        }
        let n = 0;
        for (let i = 0; i < root.children.length; i++) {
            const ch = root.children[i];
            if (typeof ch.imagePath === "string" && ch.imagePath.indexOf("panel-background") >= 0) {
                hide.createObject(ghost, { target: ch });
                n++;
            }
        }
        layers = n;
        console.warn("plasmahud: ghost panel hid", n, "background layers");
    }

    Component {
        id: hide
        Binding {
            property: "opacity"
            value: 0
            when: ghost.active
            restoreMode: Binding.RestoreBindingOrValue
        }
    }

    onActiveChanged: if (active) attach()
    Timer {
        // The panel view finishes building after its applets.
        interval: 1500
        running: ghost.active
        onTriggered: ghost.attach()
    }
}
