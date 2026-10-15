import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    property alias cfg_palette: palette.currentIndex
    property alias cfg_colorMode: colorMode.currentIndex
    property alias cfg_mode: mode.currentIndex
    property alias cfg_taskAlign: taskAlign.currentIndex
    property alias cfg_showActiveTitle: showActiveTitle.checked
    property alias cfg_groupTasks: groupTasks.checked
    property alias cfg_currentDesktopOnly: currentDesktopOnly.checked
    property alias cfg_currentScreenOnly: currentScreenOnly.checked
    property alias cfg_livePreviews: livePreviews.checked
    property alias cfg_ghostPanel: ghostPanel.checked
    property alias cfg_monoFont: monoFont.text
    property alias cfg_labelFont: labelFont.text
    property alias cfg_badgeCpu: badgeCpu.checked
    property alias cfg_badgeGpu: badgeGpu.checked
    property alias cfg_badgeMem: badgeMem.checked
    property alias cfg_badgeTemp: badgeTemp.checked
    property alias cfg_badgeNet: badgeNet.checked
    property alias cfg_badgeUptime: badgeUptime.checked
    property alias cfg_sampleMs: sampleMs.value
    property real cfg_glow
    property alias cfg_scanlines: scanlines.checked
    property alias cfg_glitch: glitch.checked
    property alias cfg_checkUpdates: checkUpdates.checked
    property alias cfg_gpuDevice: gpuDevice.text
    property alias cfg_terminalCommand: terminalCommand.text
    property alias cfg_probeCommand: probeCommand.text

    Kirigami.FormLayout {
        QQC2.ComboBox {
            id: mode
            Kirigami.FormData.label: i18n("This instance shows:")
            model: [i18n("Tasks + telemetry"), i18n("Telemetry badge only"), i18n("Task strip only")]
        }
        QQC2.CheckBox {
            id: ghostPanel
            text: i18n("Ghost panel (hide the native panel background)")
        }
        QQC2.ComboBox {
            id: palette
            Kirigami.FormData.label: i18n("Palette:")
            model: ["System accent (adaptive)", "The World (.hack)", "Neon Grid", "Synthwave", "Acid", "Amber CRT", "Icebreaker", "Bloodline", "Toxic"]
        }
        QQC2.ComboBox {
            id: colorMode
            Kirigami.FormData.label: i18n("Light / dark:")
            model: [i18n("System (follow the KDE color scheme)"), i18n("Light"), i18n("Dark")]
        }
        QQC2.TextField {
            id: monoFont
            Kirigami.FormData.label: i18n("Readout font:")
            placeholderText: "Hack"
        }
        QQC2.TextField {
            id: labelFont
            Kirigami.FormData.label: i18n("Label font:")
            placeholderText: "Fira Sans Condensed"
        }
        RowLayout {
            Kirigami.FormData.label: i18n("Glow:")
            QQC2.Slider {
                id: glow
                from: 0
                to: 1
                stepSize: 0.05
                value: cfg_glow
                onMoved: cfg_glow = value
            }
            QQC2.Label { text: Math.round(glow.value * 100) + "%" }
        }
        QQC2.CheckBox { id: scanlines; text: i18n("Scanlines and scan band") }
        QQC2.CheckBox { id: glitch; text: i18n("Glitch and sweep effects") }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Task strip") }
        QQC2.ComboBox {
            id: taskAlign
            Kirigami.FormData.label: i18n("Align:")
            model: [i18n("Start"), i18n("Center")]
        }
        QQC2.CheckBox { id: showActiveTitle; text: i18n("Expand the active task to show its title") }
        QQC2.CheckBox { id: groupTasks; text: i18n("Group windows by application") }
        QQC2.CheckBox { id: currentScreenOnly; text: i18n("Only tasks on this screen") }
        QQC2.CheckBox { id: currentDesktopOnly; text: i18n("Only tasks on the current desktop") }
        QQC2.CheckBox { id: livePreviews; text: i18n("Live window previews on hover") }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Panel badge") }
        QQC2.CheckBox { id: badgeCpu; Kirigami.FormData.label: i18n("Show:"); text: i18n("CPU load") }
        QQC2.CheckBox { id: badgeGpu; text: i18n("GPU load") }
        QQC2.CheckBox { id: badgeMem; text: i18n("Memory") }
        QQC2.CheckBox { id: badgeTemp; text: i18n("CPU / GPU temperature") }
        QQC2.CheckBox { id: badgeNet; text: i18n("Network rate") }
        QQC2.CheckBox { id: badgeUptime; text: i18n("Uptime") }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Telemetry") }
        QQC2.SpinBox {
            id: sampleMs
            Kirigami.FormData.label: i18n("Sample interval (ms):")
            from: 250
            to: 10000
            stepSize: 250
        }
        QQC2.TextField {
            id: gpuDevice
            Kirigami.FormData.label: i18n("GPU sensor:")
            placeholderText: "gpu0"
        }
        QQC2.CheckBox { id: checkUpdates; text: i18n("Check pacman updates every 30 minutes") }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Commands") }
        QQC2.TextField {
            id: terminalCommand
            Kirigami.FormData.label: i18n("Terminal:")
            placeholderText: "konsole"
        }
        QQC2.TextField {
            id: probeCommand
            Kirigami.FormData.label: i18n("Probe override:")
            placeholderText: i18n("bundled hudprobe")
        }
    }
}
