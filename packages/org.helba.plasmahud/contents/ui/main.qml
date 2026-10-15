import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore

PlasmoidItem {
    id: root

    readonly property bool inPanel: Plasmoid.formFactor === PlasmaCore.Types.Horizontal
        || Plasmoid.formFactor === PlasmaCore.Types.Vertical
    property Item bar: null

    // Always inline: the bar is the widget. The HUD popup is our own Dialog, not Plasma's
    // expanded state (a compact-only widget with no fullRepresentation renders empty).
    preferredRepresentation: fullRepresentation
    activationTogglesExpanded: false
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    toolTipMainText: ""
    toolTipSubText: ""

    Hud {
        id: ctx
        cfg: Plasmoid.configuration
        open: popup.visible
    }

    fullRepresentation: Bar {
        hud: ctx
        vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
        onBadgeActivated: popup.toggle()
        onLauncherRequested: root.toggleLauncher()
        Component.onCompleted: root.bar = this
    }

    // Meta (and the widget's own shortcut) land here: metadata.json declares this widget
    // an application launcher, so plasmashell routes the launcher key to it.
    Connections {
        target: Plasmoid
        function onActivated() { root.toggleLauncher(); }
    }

    // The launcher is built on first use; every instance can open it, so Meta opens it
    // on whichever screen plasmashell picks.
    Loader {
        id: launcher
        active: false
        sourceComponent: Launcher {
            hud: ctx
            applet: root
        }
    }
    // Meta goes to whichever HUD instance sits on the screen under the cursor; the launcher
    // always opens from the primary panel's left island instead.
    readonly property bool ownsLauncher: Plasmoid.configuration.mode === 3
    Component.onCompleted: if (ownsLauncher) Bus.launcherOwner = root
    Component.onDestruction: if (Bus.launcherOwner === root) Bus.launcherOwner = null
    onOwnsLauncherChanged: {
        if (ownsLauncher) Bus.launcherOwner = root;
        else if (Bus.launcherOwner === root) Bus.launcherOwner = null;
    }

    function toggleLauncher() {
        const owner = Bus.launcherOwner;
        if (!owner) console.warn("plasmahud: no primary left island registered; opening the launcher here");
        if (owner && owner !== root) {
            owner.toggleLauncherHere();
            return;
        }
        toggleLauncherHere();
    }
    function toggleLauncherHere() {
        launcher.active = true;
        if (!launcher.item) return;
        launcher.item.anchor = launcherAnchor();
        launcher.item.toggle();
    }

    // Plasmashell gives Meta to any HUD instance on the panel; the launcher should still
    // rise from the left island's glyph. Find it among this panel's applets, else use
    // the panel's left edge (side screens have no left island).
    function launcherAnchor() {
        let container = null;
        for (let p = root; p && p.parent; p = p.parent) {
            if (String(p.parent).indexOf("GridLayout") >= 0) { container = p; break; }
        }
        if (container) {
            const kids = container.parent.children;
            for (let i = 0; i < kids.length; i++) {
                const a = kids[i].applet;
                if (a && a.plasmoid && a.plasmoid.pluginName === Plasmoid.pluginName
                        && a.plasmoid.configuration.mode === 3 && a.bar)
                    return a.bar.launcherAnchor;
            }
        }
        return root.bar ? root.bar.edgeAnchor : null;
    }

    // Own frameless window instead of the stock applet popup, so the HUD chrome
    // is the whole surface rather than sitting inside a Breeze frame.
    PlasmaCore.Dialog {
        id: popup

        visualParent: root.bar ? root.bar.popupAnchor : null
        location: Plasmoid.location
        type: PlasmaCore.Dialog.AppletPopup
        backgroundHints: PlasmaCore.Dialog.NoBackground
        hideOnWindowDeactivate: true

        function toggle() {
            visible = !visible;
            if (visible) requestActivate();
        }

        onVisibleChanged: if (visible) {
            panel.play();
            panel.forceActiveFocus();
        }

        mainItem: HudPanel {
            id: panel
            hud: ctx
            onCloseRequested: popup.visible = false
            onCommand: (cmd, detached) => {
                popup.visible = false;
                if (detached) ctx.launch(cmd);
                else ctx.run(cmd);
            }
        }
    }

    Ghost {
        anchor: root
        active: root.inPanel && !!Plasmoid.configuration.ghostPanel
    }

}
