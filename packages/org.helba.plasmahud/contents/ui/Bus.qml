pragma Singleton
import QtQuick

// Shared by every HUD widget instance in plasmashell (one QML engine): lets an
// instance on another screen hand the launcher to the primary panel's left island.
QtObject {
    // The PlasmoidItem of the left island on the primary panel, while it exists.
    property Item launcherOwner: null
}
