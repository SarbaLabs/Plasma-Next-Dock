/*
    SPDX-FileCopyrightText: 2024 Matt Anis
    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick
import QtQuick.Shapes
import org.kde.kirigami as Kirigami

Item {
    id: root
    property var corners: [10, 10, 10, 10]
    property bool glowEnabled: false
    property bool glowHovering: false
    property point glowPosition: Qt.point(width / 2, height / 2)
    property color glowColor: Kirigami.Theme.highlightColor
    property real glowIntensity: 1
    property real glowRadius: 70
    property real glowOpacity: 0.3
    property int backgroundType: 0
    property color customBackgroundColor: Kirigami.Theme.backgroundColor
    property color lowerColor: Kirigami.Theme.highlightColor
    property int customBorderWidth: 1
    property color customBorderColor: Kirigami.Theme.disabledTextColor
    property bool isVertical: false
    property real blurOpacity: 0.35
    property real topOpacity: 1
    property real bottomOpacity: 1
    property real borderOpacity: 1
    readonly property var drawing: dockController.capsuleDrawing(Qt.size(width, height), corners, isVertical, customBorderWidth)
    function tint(color, opacity) { return Qt.rgba(color.r, color.g, color.b, opacity * color.a); }

    Shape {
        id: base
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        containsMode: Shape.FillContains
        visible: root.backgroundType !== 1
        ShapePath {
            strokeWidth: -1
            fillColor: root.tint(root.customBackgroundColor, root.backgroundType === 0 ? 1 : root.blurOpacity)
            fillGradient: root.backgroundType === 5 ? colors : null
            PathSvg { path: root.drawing.fill }
        }
    }
    property alias fillShape: base
    LinearGradient {
        id: colors
        x1: 0; y1: 0; x2: 0; y2: root.height
        GradientStop { position: 0; color: root.tint(root.customBackgroundColor, root.topOpacity) }
        GradientStop { position: 1; color: root.tint(root.lowerColor, root.bottomOpacity) }
    }
    Loader {
        id: glowLoader
        objectName: "glowLoader"
        anchors.fill: parent
        active: root.glowEnabled && root.backgroundType !== 1
        sourceComponent: CapsuleGlow {
            silhouette: root.drawing.fill
            pointerX: root.glowPosition.x
            pointerY: root.glowPosition.y
            glowRadius: Math.max(1, root.glowRadius)
            intensity: root.glowIntensity
            strength: root.glowOpacity
            hovering: root.glowHovering
            glowColor: root.glowColor
        }
    }
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        visible: root.backgroundType === 4
        ShapePath {
            strokeWidth: -1
            fillGradient: LinearGradient {
                x2: root.isVertical ? root.width : 0
                y2: root.isVertical ? 0 : root.height
                GradientStop { position: 0; color: "#29ffffff" }
                GradientStop { position: 0.35; color: "#0affffff" }
                GradientStop { position: 0.75; color: "#03ffffff" }
                GradientStop { position: 1; color: "#0fffffff" }
            }
            PathSvg { path: root.drawing.fill }
        }
    }
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        visible: root.backgroundType !== 1 && root.customBorderWidth > 0 && root.borderOpacity > 0
        ShapePath {
            strokeWidth: -1
            fillRule: ShapePath.OddEvenFill
            fillColor: root.tint(root.customBorderColor, root.borderOpacity)
            PathSvg { path: root.drawing.outline }
        }
    }
}
