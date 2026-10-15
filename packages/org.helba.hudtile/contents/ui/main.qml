import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import "../../../org.helba.plasmahud/contents/ui"

// HUD Tile: one card of the HUD popup as a free-standing desktop widget. Add several and
// pick a card for each (telemetry, cores, load, net, processes, system, command deck).
PlasmoidItem {
    id: root

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    Hud {
        id: ctx
        cfg: Plasmoid.configuration
        open: true
    }

    readonly property int card: Math.max(0, Math.min(6, Plasmoid.configuration.card))
    // Starting size of each card on the desktop; resizable from there.
    readonly property var sizes: [[640, 210], [560, 116], [400, 150], [400, 150], [460, 250], [340, 230], [660, 56]]

    fullRepresentation: Item {
        Layout.minimumWidth: 200
        Layout.minimumHeight: 48
        Layout.preferredWidth: root.sizes[root.card][0]
        Layout.preferredHeight: root.sizes[root.card][1]

        Loader {
            anchors.fill: parent
            anchors.margins: 6
            sourceComponent: [gauges, cores, load, net, procs, system, deck][root.card]
        }
    }

    Component { id: gauges; GaugesCard { hud: ctx } }
    Component { id: cores; CoresCard { hud: ctx } }
    Component { id: load; LoadCard { hud: ctx } }
    Component { id: net; NetCard { hud: ctx } }
    Component { id: procs; ProcsCard { hud: ctx; rows: Plasmoid.configuration.processRows } }
    Component { id: system; SystemCard { hud: ctx } }
    Component {
        id: deck
        DeckCard {
            hud: ctx
            onCommand: (cmd, detached) => detached ? ctx.launch(cmd) : ctx.run(cmd)
        }
    }
}
