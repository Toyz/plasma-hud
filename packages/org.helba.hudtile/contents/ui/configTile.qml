import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    property alias cfg_card: card.currentIndex
    property alias cfg_processRows: processRows.value
    property alias cfg_palette: palette.currentIndex
    property alias cfg_colorMode: colorMode.currentIndex
    property alias cfg_sampleMs: sampleMs.value

    Kirigami.FormLayout {
        QQC2.ComboBox {
            id: card
            Kirigami.FormData.label: i18n("Card:")
            model: [i18n("Telemetry gauges"), i18n("Core matrix"), i18n("Load trace"), i18n("Net link"),
                i18n("Processes"), i18n("System"), i18n("Command deck")]
        }
        QQC2.SpinBox {
            id: processRows
            Kirigami.FormData.label: i18n("Process rows:")
            visible: card.currentIndex === 4
            from: 3
            to: 20
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
        QQC2.SpinBox {
            id: sampleMs
            Kirigami.FormData.label: i18n("Sample every (ms):")
            from: 250
            to: 10000
            stepSize: 250
        }
    }
}
