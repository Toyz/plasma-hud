import QtQuick
import org.kde.plasma.plasmoid

// HUD Shader Wall. Each screen's desktop containment has its own instance and its
// own config, so every monitor runs its own effect, image, palette and seed.
WallpaperItem {
    id: root

    Wall {
        id: wall
        anchors.fill: parent
        cfg: root.configuration
    }

    // Feed Plasma's "accent colour from wallpaper".
    accentColor: root.configuration.PublishAccent ? wall.accent : "transparent"
}
