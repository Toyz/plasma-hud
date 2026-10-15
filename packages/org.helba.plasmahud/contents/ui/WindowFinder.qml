import QtQuick
import org.kde.taskmanager as TaskManager

// Finds a running app's window so launching it again brings that window forward
// instead of opening a second copy.
Item {
    id: finder

    visible: false

    TaskManager.ActivityInfo { id: activities }
    TaskManager.TasksModel {
        id: windows
        groupMode: TaskManager.TasksModel.GroupDisabled
        activity: activities.currentActivity
        filterByActivity: true
    }

    // "applications:org.kde.systemsettings.desktop" -> "org.kde.systemsettings"
    function appIdOf(storageId) {
        return String(storageId || "").replace(/^applications:/, "").replace(/\.desktop$/, "").toLowerCase();
    }

    // Activate the most recently used window of the app; true when one was found.
    function raiseApp(storageId) {
        const want = appIdOf(storageId);
        if (!want) return false;
        const R = TaskManager.AbstractTasksModel;
        let best = -1, bestTime = -1;
        for (let i = 0; i < windows.count; i++) {
            const ix = windows.makeModelIndex(i);
            if (windows.data(ix, R.IsLauncher) || windows.data(ix, R.IsStartup)) continue;
            const app = String(windows.data(ix, R.AppId) || "").toLowerCase();
            const launcher = appIdOf(String(windows.data(ix, R.LauncherUrlWithoutIcon) || "").split("/").pop());
            if (app !== want && launcher !== want) continue;
            const t = windows.data(ix, R.LastActivated);
            const when = t ? new Date(t).getTime() : 0;
            if (when > bestTime) { best = i; bestTime = when; }
        }
        if (best < 0) return false;
        windows.requestActivate(windows.makeModelIndex(best));
        return true;
    }
}
