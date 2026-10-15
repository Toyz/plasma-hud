import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.private.kicker as Kicker

// The HUD app launcher: a frameless popup over Plasma's kicker models.
//   root model      all apps + categories (refreshed on open)
//   favorites       pinned apps, KActivities-backed, migrated once from kickoff
//   runner model    KRunner search: apps, files, calculator, commands, ...
// An invisible Item owns the models: a Dialog's default property only takes visual items.
Item {
    id: launcher

    required property QtObject hud
    required property Item applet          // the PlasmoidItem (kicker's appletInterface)
    property Item anchor: null
    readonly property bool open: dialog.visible

    visible: false

    function toggle() {
        if (dialog.visible) {
            dialog.visible = false;
            return;
        }
        rootModel.refresh();
        panel.reset();
        dialog.visible = true;
        dialog.requestActivate();
        panel.focusSearch();
    }

    readonly property string favoritesClient: "org.helba.plasmahud.favorites"
    // The stock launcher the HUD layout replaced (its favorites are migrated once).
    readonly property string kickoffClient: "org.kde.plasma.kickoff.favorites.instance-48"

    Kicker.RootModel {
        id: rootModel
        autoPopulate: false
        appletInterface: launcher.applet
        appNameFormat: 0
        flat: true
        sorted: true
        showSeparators: false
        showAllApps: true
        showAllAppsCategorized: false
        showTopLevelItems: false
        showRecentApps: false
        showRecentDocs: false
        showPowerSession: false

        Component.onCompleted: {
            favoritesModel.initForClient(launcher.favoritesClient);
            if (!launcher.hud.cfg.favoritesMigrated) migrate.active = true;
        }
    }

    // One-shot import of the old kickoff favorites.
    Loader {
        id: migrate
        active: false
        sourceComponent: Kicker.KAStatsFavoritesModel {
            Component.onCompleted: {
                initForClient(launcher.kickoffClient);
                Qt.callLater(() => {
                    const fav = rootModel.favoritesModel;
                    if (fav.count === 0)
                        for (const id of favorites) fav.addFavorite(id, -1);
                    launcher.hud.cfg.favoritesMigrated = true;
                    migrate.active = false;
                });
            }
        }
    }

    Kicker.RunnerModel {
        id: runnerModel
        appletInterface: launcher.applet
        favoritesModel: rootModel.favoritesModel
        mergeResults: true
    }

    Kicker.ProcessRunner { id: processRunner }

    PlasmaCore.Dialog {
        id: dialog
        location: Plasmoid.location
        type: PlasmaCore.Dialog.AppletPopup
        backgroundHints: PlasmaCore.Dialog.NoBackground
        hideOnWindowDeactivate: true
        visualParent: launcher.anchor

        mainItem: LauncherPanel {
            id: panel
            hud: launcher.hud
            rootModel: rootModel
            runnerModel: runnerModel
            favorites: rootModel.favoritesModel
            onCloseRequested: dialog.visible = false
            onCommand: (cmd, detached) => {
                dialog.visible = false;
                if (detached) launcher.hud.launch(cmd);
                else launcher.hud.run(cmd);
            }
            onEditMenu: {
                dialog.visible = false;
                processRunner.runMenuEditor();
            }
        }
    }
}
