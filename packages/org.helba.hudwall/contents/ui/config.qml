import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Dialogs as Dialogs
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.FormLayout {
    id: page

    property alias cfg_Image: image.text
    property alias cfg_FillMode: fill.currentValue
    property alias cfg_Effect: effect.currentIndex
    property real cfg_Intensity
    property real cfg_ColorDrift
    property real cfg_Speed
    property alias cfg_Palette: palette.currentIndex
    property alias cfg_Fps: fps.value
    property alias cfg_PauseWhenCovered: pause.checked
    property alias cfg_Span: span.checked
    property alias cfg_PublishAccent: publish.checked

    RowLayout {
        Kirigami.FormData.label: i18n("Image:")
        QQC2.TextField {
            id: image
            Layout.preferredWidth: Kirigami.Units.gridUnit * 18
            placeholderText: i18n("file:///path/to/wallpaper.png")
        }
        QQC2.Button {
            icon.name: "document-open"
            onClicked: picker.open()
        }
    }
    Dialogs.FileDialog {
        id: picker
        nameFilters: [i18n("Images (*.png *.jpg *.jpeg *.webp *.avif *.jxl *.bmp)")]
        onAccepted: image.text = selectedFile.toString()
    }
    QQC2.ComboBox {
        id: fill
        Kirigami.FormData.label: i18n("Positioning:")
        textRole: "text"
        valueRole: "value"
        model: [
            { text: i18n("Scaled and cropped"), value: Image.PreserveAspectCrop },
            { text: i18n("Scaled, keep proportions"), value: Image.PreserveAspectFit },
            { text: i18n("Stretched"), value: Image.Stretch },
            { text: i18n("Centered"), value: Image.Pad },
            { text: i18n("Tiled"), value: Image.Tile }
        ]
        Component.onCompleted: currentIndex = Math.max(0, indexOfValue(page.cfg_FillMode))
    }

    Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Effect") }

    QQC2.ComboBox {
        id: effect
        Kirigami.FormData.label: i18n("Effect:")
        model: [
            i18n("Chroma drift (colored pixels slowly shift hue)"),
            i18n("Data Drain (.hack: the picture lifts away as data cells)"),
            i18n("Depth parallax (brightness as 3D depth)"),
            i18n("Living ink (flows along the image's contours)"),
            i18n("Pixel sort melt"),
            i18n("Image-seeded growth (reaction-diffusion)"),
            i18n("Emissive bloom"),
            i18n("Edge neon pulse"),
            i18n("Hue cycle waves"),
            i18n("Halftone CRT"),
            i18n("Overlay: domain-warped plasma"),
            i18n("Overlay: gyroid lattice"),
            i18n("Overlay: synth grid"),
            i18n("Overlay: datamosh"),
            i18n("Overlay: hex lens"),
            i18n("Overlay: reaction-diffusion"),
            i18n("None (plain image)")
        ]
    }
    component Amount: RowLayout {
        id: amt
        property real value
        signal moved(real v)
        QQC2.Slider {
            id: sl
            from: 0
            to: 1
            stepSize: 0.05
            value: amt.value
            onMoved: amt.moved(value)
        }
        QQC2.Label { text: Math.round(sl.value * 100) + "%" }
    }
    Amount {
        Kirigami.FormData.label: i18n("Strength:")
        value: page.cfg_Intensity
        onMoved: v => page.cfg_Intensity = v
    }
    Amount {
        Kirigami.FormData.label: i18n("Color drift (stacks on any effect):")
        value: page.cfg_ColorDrift
        onMoved: v => page.cfg_ColorDrift = v
    }
    RowLayout {
        Kirigami.FormData.label: i18n("Speed:")
        QQC2.Slider {
            id: speed
            from: 0.1
            to: 3
            stepSize: 0.1
            value: page.cfg_Speed
            onMoved: page.cfg_Speed = value
        }
        QQC2.Label { text: speed.value.toFixed(1) + "x" }
    }
    QQC2.ComboBox {
        id: palette
        Kirigami.FormData.label: i18n("Accent colors:")
        model: [i18n("System accent"), i18n("From this screen's image"), "Neon Grid", "Synthwave", "Acid",
                "Amber CRT", "Icebreaker", "Bloodline", "Toxic"]
    }

    Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Performance") }

    QQC2.SpinBox {
        id: fps
        Kirigami.FormData.label: i18n("Frame rate cap:")
        from: 5
        to: 240
    }
    QQC2.CheckBox { id: pause; text: i18n("Pause while a maximized or fullscreen window covers this screen") }
    QQC2.CheckBox { id: span; text: i18n("Continuous across all screens (span coordinates)") }
    QQC2.CheckBox { id: publish; text: i18n("Provide accent color to Plasma (for \"accent from wallpaper\")") }
}
