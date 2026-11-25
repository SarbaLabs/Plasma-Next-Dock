// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes

Item {
    id: shadow
    required property Item capsule
    required property int padding
    required property real radius
    required property real offsetX
    required property real offsetY
    required property real strength
    required property color tint

    // Both textures describe geometry only. Fill, halo and border opacity
    // must never modulate the shadow or expose it underneath the capsule.
    Item {
        id: mask
        anchors.fill: parent
        visible: false
        layer.enabled: true
        Shape {
            x: shadow.padding; y: shadow.padding
            width: shadow.capsule.width; height: shadow.capsule.height
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: "white"
                strokeColor: "white"
                strokeWidth: shadow.capsule.customBorderWidth > 0 ? 2 * shadow.capsule.customBorderWidth : -1
                joinStyle: ShapePath.RoundJoin
                PathSvg { path: shadow.capsule.drawing.fill }
            }
        }
    }
    MultiEffect {
        id: blurred
        anchors.fill: parent
        visible: false
        layer.enabled: true
        source: mask
        autoPaddingEnabled: false
        blurEnabled: shadow.radius > 0
        blurMax: Math.max(1, shadow.radius)
        blur: 1
    }
    ShaderEffect {
        anchors.fill: parent
        opacity: shadow.strength
        property var silhouette: mask
        property var softness: blurred
        property vector2d shift: Qt.vector2d(shadow.offsetX / Math.max(1, width), shadow.offsetY / Math.max(1, height))
        property color tint: shadow.tint
        fragmentShader: "qrc:/shaders/exteriorshadow.frag.qsb"
    }
}
