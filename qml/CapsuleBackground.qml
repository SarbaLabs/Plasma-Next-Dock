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
    readonly property bool drawGlow: glowEnabled && glowIntensity > 0 && glowOpacity > 0
        && (backgroundType === 5 ? desktopTint.a > 0 || screenTint.a > 0 : backgroundType !== 0 || tintOpacity > 0)
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
    property int edge: 0
    readonly property bool isVertical: edge >= 2
    // Both gradients run from the desktop-facing side toward the physical edge.
    readonly property point desktopSide: Qt.point(edge === 2 ? width : 0, edge === 1 ? height : 0)
    readonly property point screenSide: Qt.point(edge === 3 ? width : 0, edge === 0 ? height : 0)
    property real midpoint: 0.5
    property real tintOpacity: 1
    property real topOpacity: 1
    property real bottomOpacity: 1
    property real borderOpacity: 1
    readonly property var drawing: dockController.capsuleDrawing(Qt.size(width, height), corners, isVertical, customBorderWidth)
    function tint(color, opacity) { return Qt.rgba(color.r, color.g, color.b, opacity * color.a); }

    readonly property color desktopTint: tint(customBackgroundColor, topOpacity)
    readonly property color screenTint: tint(lowerColor, bottomOpacity)
    readonly property bool varyingGradient: backgroundType === 5 && !Qt.colorEqual(desktopTint, screenTint)

    Shape {
        id: base
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        containsMode: Shape.FillContains
        ShapePath {
            strokeWidth: -1
            fillColor: root.backgroundType === 5 ? root.desktopTint : root.tint(root.customBackgroundColor, root.tintOpacity)
            fillGradient: root.varyingGradient ? colors : null
            PathSvg { path: root.drawing.fill }
        }
    }
    property alias fillShape: base
    LinearGradient {
        id: colors
        x1: root.desktopSide.x; y1: root.desktopSide.y
        x2: root.screenSide.x; y2: root.screenSide.y
        GradientStop { position: 0; color: root.desktopTint }
        GradientStop {
            position: root.midpoint
            color: {
                const a = root.desktopTint, b = root.screenTint, sum = a.a + b.a;
                if (!sum) return "transparent";
                return Qt.rgba((a.r*a.a + b.r*b.a) / sum, (a.g*a.a + b.g*b.a) / sum,
                               (a.b*a.a + b.b*b.a) / sum, sum / 2);
            }
        }
        GradientStop { position: 1; color: root.screenTint }
    }
    Loader {
        id: glowLoader
        objectName: "glowLoader"
        anchors.fill: parent
        active: root.drawGlow
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
                x1: root.desktopSide.x; y1: root.desktopSide.y
                x2: root.screenSide.x; y2: root.screenSide.y
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
        visible: root.customBorderWidth > 0 && root.borderOpacity > 0
        ShapePath {
            strokeWidth: -1
            fillRule: ShapePath.OddEvenFill
            fillColor: root.tint(root.customBorderColor, root.borderOpacity)
            PathSvg { path: root.drawing.outline }
        }
    }
}
