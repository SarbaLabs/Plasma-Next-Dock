// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Effects
import org.kde.kirigami as Kirigami

Item {
    id: artwork
    required property real maximumSize
    required property real paintedSize
    required property int shadowPadding
    required property bool shadowEnabled
    required property bool highlighted
    required property var iconSource
    required property QtObject paletteSource
    // Keep the shadow render targets at a stable resolution
    // while the painted icon moves and grows inside them.
    width: artwork.maximumSize + 2 * artwork.shadowPadding
    height: width
    layer.enabled: artwork.shadowEnabled
    layer.effect: MultiEffect {
        autoPaddingEnabled: false
        shadowEnabled: true
        blurMax: Math.max(1, dockOptions.iconShadowSize ?? 0)
        shadowBlur: dockOptions.iconShadowSize > 0 ? 1 : 0
        shadowHorizontalOffset: dockOptions.iconShadowX ?? 0
        shadowVerticalOffset: dockOptions.iconShadowY ?? 2
        shadowOpacity: (dockOptions.iconShadowStrength ?? 0) / 100
        shadowColor: artwork.paletteSource.resolve(dockOptions.iconShadowRole, dockOptions.iconShadowColor ?? "black", artwork.paletteSource.shadowColor)
    }
    Kirigami.Icon {
        anchors.centerIn: parent
        width: artwork.maximumSize; height: width
        scale: width > 0 ? artwork.paintedSize / width : 1
        smooth: true
        source: artwork.iconSource
        roundToIconSize: false
        active: artwork.highlighted
        layer.enabled: dockOptions.grayscaleIcons === true
        layer.smooth: true
        layer.effect: ShaderEffect {
            property color tint: artwork.paletteSource.resolve(dockOptions.iconTintRole, dockOptions.iconTintColor, Kirigami.Theme.highlightColor)
            property real strength: dockOptions.tintIcons ? dockOptions.iconTintSaturation / 100 : 0
            fragmentShader: "qrc:/shaders/iconcolor.frag.qsb"
        }
    }
}
