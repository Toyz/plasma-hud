import QtQuick
import QtQuick.Layouts

// Command deck: launchers plus hold-to-confirm power actions.
// Part of the HUD popup, and a desktop widget of its own (org.helba.hudtile).
RowLayout {
    id: c
    required property QtObject hud
    property real boot: 1
    signal command(string cmd, bool detached)

    spacing: 6
    opacity: Math.max(0, Math.min(1, c.boot * 6 - 3.6))

    ActionButton {
        hud: c.hud; label: "TERM"; code: "01"
        onTriggered: c.command(c.hud.cfg.terminalCommand, true)
    }
    ActionButton {
        hud: c.hud; label: "SYSMON"; code: "02"
        onTriggered: c.command("plasma-systemmonitor", true)
    }
    ActionButton {
        hud: c.hud; label: "FILES"; code: "03"
        onTriggered: c.command("dolphin", true)
    }
    ActionButton {
        hud: c.hud; label: "CAPTURE"; code: "04"
        onTriggered: c.command("spectacle -r", true)
    }
    ActionButton {
        hud: c.hud; label: "LOCK"; code: "05"
        onTriggered: c.command("loginctl lock-session", false)
    }
    Item { Layout.fillWidth: true }
    ActionButton {
        hud: c.hud; label: "SLEEP"; code: "F1"; holdMs: 700
        tone: c.hud.warn
        onTriggered: c.command("systemctl suspend", false)
    }
    ActionButton {
        hud: c.hud; label: "REBOOT"; code: "F2"; holdMs: 1100
        tone: c.hud.crit
        onTriggered: c.command("qdbus6 org.kde.Shutdown /Shutdown logoutAndReboot", false)
    }
    ActionButton {
        hud: c.hud; label: "HALT"; code: "F3"; holdMs: 1100
        tone: c.hud.crit
        onTriggered: c.command("qdbus6 org.kde.Shutdown /Shutdown logoutAndShutdown", false)
    }
}
