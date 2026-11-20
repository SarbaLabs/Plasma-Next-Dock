// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtTest
TestCase {
    name: "CapsuleBackground"
    when: windowShown
    visible: true
    width: 400; height: 120
    function test_uniformGradient_data() {
        return [0, 0.4, 1].map(opacity => ({tag: "opacity" + opacity, opacity: opacity}));
    }
    function test_uniformGradient(data) {
        const component = Qt.createComponent("qrc:/qml/CapsuleBackground.qml");
        const item = createTemporaryObject(component, this, {width: 150, height: 72,
            customBackgroundColor: "#5080aa", lowerColor: "#5080aa", customBorderWidth: 0,
            tintOpacity: data.opacity, topOpacity: data.opacity, bottomOpacity: data.opacity});
        verify(item);
        waitForRendering(item);
        const solid = grabImage(item);
        item.backgroundType = 5;
        item.tintOpacity = 1 - data.opacity; // Independent saved Solid setting.
        for (const midpoint of [0.01, 0.5, 0.99]) {
            item.midpoint = midpoint;
            verify(!item.varyingGradient);
            verify(solid.equals(grabImage(item)));
        }
        item.glowEnabled = true;
        compare(item.drawGlow, data.opacity > 0);
        item.bottomOpacity = data.opacity === 1 ? 0.5 : 1;
        verify(item.varyingGradient);
        item.bottomOpacity = item.topOpacity = 1;
        item.lowerColor = "#bb3300";
        verify(item.varyingGradient);
    }
    function test_modesAndRadius_data() {
        return [0, 4, 5].map(mode => ({tag: "mode" + mode, mode: mode}));
    }
    function test_modesAndRadius(data) {
        const component = Qt.createComponent("qrc:/qml/CapsuleBackground.qml");
        compare(component.status, Component.Ready, component.errorString());
        const item = component.createObject(this, {width: 300, height: 50, corners: [0, 10, -10, -20],
            backgroundType: data.mode, glowEnabled: true});
        verify(item !== null);
        compare(item.fillShape.visible, true);
        const ends = [[0,0,0,50], [0,50,0,0], [300,0,0,0], [0,0,300,0]];
        for (let edge = 0; edge < 4; ++edge) {
            item.edge = edge;
            compare([item.desktopSide.x, item.desktopSide.y, item.screenSide.x, item.screenSide.y], ends[edge]);
        }
        verify(item.drawing.fill.length > 0);
        verify(item.drawing.outline.length > 0);
        const glow = findChild(item, "glowLoader");
        compare(glow.active, true);
        if (glow.active) compare(glow.item.silhouette, item.drawing.fill);
        item.customBorderWidth = 0;
        compare(item.drawing.outline, "");
        item.glowEnabled = true;
        item.glowRadius = 116; item.glowIntensity = 1.5; item.glowOpacity = 0.65;
        compare(glow.item.glowRadius, 116);
        compare(glow.item.intensity, 1.5);
        compare(glow.item.strength, 0.65);
        item.glowOpacity = 0;
        compare(glow.active, false);
        item.glowOpacity = 0.65; item.glowIntensity = 0;
        compare(glow.active, false);
        item.destroy();
    }
}
