/*
    SPDX-FileCopyrightText: 2024 Matt Anis
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import org.kde.kirigami as Kirigami
import "code/CapsuleGeometry.js" as Geometry

Item {
    id: root

    property real radius: 10
    readonly property real effectiveRadius: Geometry.radius(width, height, true, radius)
    property bool glowEnabled: false
    property bool glowHovering: false
    property point glowPosition: Qt.point(width / 2, height / 2)
    property color glowColor: Kirigami.Theme.highlightColor
    property real glowIntensity: 1
    property real glowRadius: 70
    property real glowOpacity: 0.3
    property int backgroundType: 0 // 0 = Solid, 1 = Transparent, 2 = Translucent, 3 = SystemBlur, 4 = LiquidGlass
    property color customBackgroundColor: Kirigami.Theme.backgroundColor
    property int customBorderWidth: 1
    property color customBorderColor: Kirigami.Theme.disabledTextColor
    property bool isVertical: false

    property real blurOpacity: 0.35

    // The standalone host owns blur/contrast; this component only paints.

    // ==========================================
    // MODE 0: SOLID BACKGROUND
    // ==========================================
    Rectangle {
        id: solidBackground
        objectName: "solidBackground"
        visible: root.backgroundType === 0
        anchors.fill: parent
        radius: root.effectiveRadius
        color: root.customBackgroundColor
        border.color: !glowLoader.active && root.customBorderWidth > 0 ? root.customBorderColor : "transparent"
        border.width: root.customBorderWidth
    }

    // ==========================================
    // MODE 2: TRANSLUCENT & MODE 3: SYSTEM BLUR
    // (Translucent is pure QML tint; System Blur adds KWin blur behind it)
    // ==========================================
    Rectangle {
        id: translucentOrBlurBackground
        objectName: "tintedBackground"
        visible: root.backgroundType === 2 || root.backgroundType === 3
        anchors.fill: parent
        radius: root.effectiveRadius
        color: Qt.rgba(root.customBackgroundColor.r, root.customBackgroundColor.g, root.customBackgroundColor.b, root.blurOpacity)
        border.color: !glowLoader.active && root.customBorderWidth > 0 ? root.customBorderColor : "transparent"
        border.width: root.customBorderWidth
    }

    // ==========================================
    // MODE 4: LIQUID GLASS
    // ==========================================
    Item {
        id: liquidGlassContainer
        objectName: "glassBackground"
        visible: root.backgroundType === 4
        anchors.fill: parent

        // Single clean glass base rectangle with crisp border
        Rectangle {
            id: glassBase
            anchors.fill: parent
            radius: root.effectiveRadius
            color: {
                const isDark = Kirigami.Theme.backgroundColor.hslLightness < 0.5;
                return isDark
                    ? Qt.rgba(0.12, 0.12, 0.15, root.blurOpacity)
                    : Qt.rgba(0.96, 0.97, 1.0, root.blurOpacity);
            }
            border.color: !glowLoader.active && root.customBorderWidth > 0 ? root.customBorderColor : "transparent"
            border.width: root.customBorderWidth
        }
    }
    Loader {
        id: glowLoader
        objectName: "glowLoader"
        anchors.fill: parent
        active: root.glowEnabled && root.backgroundType !== 1
        sourceComponent: CapsuleGlow {
            cornerRadius: root.effectiveRadius
            pointerX: root.glowPosition.x
            pointerY: root.glowPosition.y
            glowRadius: Math.max(1, root.glowRadius)
            intensity: Math.max(0, Math.min(2, root.glowIntensity))
            strength: Math.max(0, Math.min(1, root.glowOpacity))
            hovering: root.glowHovering
            glowColor: root.glowColor
        }
    }
    // Gloss and border stay above the optional glow.
    Item {
        anchors.fill: parent
        visible: root.backgroundType === 4
        // Internal gloss sheen inset safely inside the border
        Rectangle {
            anchors.fill: parent
            anchors.margins: Math.max(0, root.customBorderWidth)
            radius: Math.max(0, root.effectiveRadius - root.customBorderWidth)
            color: "transparent"
            gradient: Gradient {
                orientation: root.isVertical ? Gradient.Horizontal : Gradient.Vertical
                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.16) }
                GradientStop { position: 0.35; color: Qt.rgba(1, 1, 1, 0.04) }
                GradientStop { position: 0.75; color: Qt.rgba(1, 1, 1, 0.01) }
                GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.06) }
            }
        }
    }
    Rectangle {
        anchors.fill: parent
        visible: glowLoader.active && root.customBorderWidth > 0
        radius: root.effectiveRadius
        color: "transparent"
        border.width: root.customBorderWidth
        border.color: root.customBorderColor
    }

}
