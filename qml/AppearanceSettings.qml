// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Controls.ScrollView {
    id: page
    required property QtObject paletteSource
    readonly property bool freeLayout: layoutMode.currentIndex === 1

    readonly property alias extended: extendDock.checked

    function load(v) {
        layoutMode.currentIndex = v.freeLayout ? 1 : 0;
        thickness.value = v.capsuleThickness;
        iconOffset.value = v.iconOffset;
        dockShadowX.value = v.dockShadowX;
        dockShadowY.value = v.dockShadowY;
        dockShadowColor.role = v.dockShadowRole;
        dockShadowColor.fixedColor = v.dockShadowColor;
        dockShadowStrength.value = v.dockShadowStrength;
        dockShadowSize.value = v.dockShadowSize;
        glow.checked = v.glow;
        glowRadius.value = v.glowRadius;
        glowIntensity.value = v.glowIntensity;
        glowOpacity.value = v.glowOpacity;
        backgroundType.currentIndex = backgroundType.modeIds.indexOf(v.backgroundType);
        systemBlur.checked = v.systemBlur;
        extendDock.checked = v.extendDock ?? false;
        midpoint.value = v.gradientMidpoint;
        glassOpacity.value = Math.round(v.glassOpacity * 100);
        backgroundOpacity.value = Math.round(v.backgroundOpacity * 100);
        borderWidth.value = v.borderWidth;
        borderOpacity.value = Math.round(v.borderOpacity * 100);
        topOpacity.value = Math.round(v.gradientTopOpacity * 100);
        bottomOpacity.value = Math.round(v.gradientBottomOpacity * 100);
        fill.role = v.backgroundRole;
        fill.fixedColor = v.backgroundColor;
        upper.role = v.gradientTopRole;
        upper.fixedColor = v.gradientTopColor;
        lower.role = v.gradientBottomRole;
        lower.fixedColor = v.gradientBottomColor;
        outline.role = v.borderRole;
        outline.fixedColor = v.borderColor;
        linkCorners.checked = v.linkCornerRadii;
        topLeft.value = v.topLeftRadius;
        topRight.value = v.topRightRadius;
        bottomLeft.value = v.bottomLeftRadius;
        bottomRight.value = v.bottomRightRadius;
        horizontalPadding.value = v.horizontalPadding;
        verticalPadding.value = v.verticalPadding;
    }

    // Return only this page's keys so applying a draft preserves unrelated profile changes.
    function draft() {
        return {
            freeLayout: layoutMode.currentIndex === 1,
            capsuleThickness: thickness.value,
            iconOffset: iconOffset.value,
            backgroundType: backgroundType.mode,
            systemBlur: systemBlur.checked,
            extendDock: extendDock.checked,
            gradientMidpoint: midpoint.value,
            glassOpacity: glassOpacity.value / 100,
            backgroundOpacity: backgroundOpacity.value / 100,
            borderWidth: borderWidth.value,
            borderRole: outline.role,
            borderColor: outline.fixedColor.toString(),
            borderOpacity: borderOpacity.value / 100,
            dockShadowX: dockShadowX.value,
            dockShadowY: dockShadowY.value,
            dockShadowRole: dockShadowColor.role,
            dockShadowColor: dockShadowColor.fixedColor.toString(),
            dockShadowStrength: dockShadowStrength.value,
            dockShadowSize: dockShadowSize.value,
            backgroundRole: fill.role,
            backgroundColor: fill.fixedColor.toString(),
            gradientTopRole: upper.role,
            gradientTopColor: upper.fixedColor.toString(),
            gradientTopOpacity: topOpacity.value / 100,
            gradientBottomRole: lower.role,
            gradientBottomColor: lower.fixedColor.toString(),
            gradientBottomOpacity: bottomOpacity.value / 100,
            horizontalPadding: horizontalPadding.value,
            verticalPadding: verticalPadding.value,
            linkCornerRadii: linkCorners.checked,
            topLeftRadius: topLeft.value,
            topRightRadius: topRight.value,
            bottomLeftRadius: bottomLeft.value,
            bottomRightRadius: bottomRight.value,
            glow: glow.checked,
            glowRadius: glowRadius.value,
            glowIntensity: glowIntensity.value,
            glowOpacity: glowOpacity.value
        };
    }

    contentWidth: availableWidth
    ColumnLayout {
        width: parent.width
        spacing: Kirigami.Units.largeSpacing
        SettingsForm {
            Layout.fillWidth: true
            Controls.ComboBox {
                id: layoutMode
                objectName: "layoutModeControl"
                Kirigami.FormData.label: i18n("Mode:")
                model: [i18n("Centered"), i18n("Free")]
            }
            Controls.SpinBox {
                id: thickness
                objectName: "capsuleThicknessControl"
                visible: layoutMode.currentIndex === 1
                Kirigami.FormData.label: i18n("Capsule thickness (px):")
                from: 1; to: 256; editable: true
            }
            Controls.SpinBox {
                id: iconOffset
                objectName: "iconOffsetControl"
                visible: layoutMode.currentIndex === 1
                Kirigami.FormData.label: i18n("Icon offset (px):")
                from: -256; to: 256; editable: true
            }
            Controls.ComboBox {
                id: backgroundType; objectName: "backgroundTypeControl"
                implicitWidth: Kirigami.Units.gridUnit * 16
                Kirigami.FormData.label: i18n("Background:")
                readonly property var modeIds: [0, 4, 5]
                readonly property int mode: modeIds[currentIndex] ?? 0
                model: [i18n("Solid"), i18n("Liquid Glass"), i18n("Gradient")]
            }
            ColorSetting {
                id: fill; objectName: "fillColorControl"; paletteSource: page.paletteSource
                Kirigami.FormData.label: i18n("Background color:")
                visible: backgroundType.mode !== 5
                defaultColor: backgroundType.mode !== 4 ? Kirigami.Theme.backgroundColor : Kirigami.Theme.backgroundColor.hslLightness < 0.5 ? "#1f1f26" : "#f5f7ff"
            }
            Controls.SpinBox {
                id: backgroundOpacity; objectName: "backgroundOpacityControl"
                visible: backgroundType.mode === 0
                Kirigami.FormData.label: i18n("Background tint opacity (%):")
                from: 0; to: 100; editable: true
            }
            Controls.SpinBox {
                id: glassOpacity; objectName: "glassOpacityControl"
                visible: backgroundType.mode === 4
                Kirigami.FormData.label: i18n("Background tint opacity (%):")
                from: 0; to: 100; editable: true
            }
            ColorSetting {
                id: upper; objectName: "upperColorControl"; paletteSource: page.paletteSource
                Kirigami.FormData.label: i18n("Desktop-side color:")
                visible: backgroundType.mode === 5
                defaultColor: Kirigami.Theme.backgroundColor
            }
            Controls.SpinBox {
                id: topOpacity; objectName: "topOpacityControl"; Kirigami.FormData.label: i18n("Desktop-side opacity (%):")
                from: 0; to: 100; editable: true
                visible: backgroundType.mode === 5
            }
            ColorSetting {
                id: lower; objectName: "lowerColorControl"; paletteSource: page.paletteSource
                Kirigami.FormData.label: i18n("Screen-edge color:")
                visible: backgroundType.mode === 5
                defaultColor: Kirigami.Theme.highlightColor
            }
            Controls.SpinBox {
                id: bottomOpacity; objectName: "bottomOpacityControl"; Kirigami.FormData.label: i18n("Screen-edge opacity (%):")
                from: 0; to: 100; editable: true
                visible: backgroundType.mode === 5
            }
            Controls.SpinBox {
                id: midpoint; objectName: "gradientMidpointControl"
                visible: backgroundType.mode === 5
                Kirigami.FormData.label: i18n("Gradient midpoint (% toward screen edge):")
                from: 1; to: 99; editable: true
            }
            Controls.CheckBox { id: systemBlur; objectName: "systemBlurControl"; text: i18n("Use system blur") }
            Controls.CheckBox { id: extendDock; objectName: "extendDockControl"; text: i18n("Extend the dock") }
            Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Corners and border") }
            RowLayout {
                id: corners
                Kirigami.FormData.label: i18n("Corner radii (px):")
                function sync(value) {
                    if (linkCorners.checked)
                        for (const corner of [topLeft, topRight, bottomLeft, bottomRight])
                            corner.value = value;
                }
                GridLayout {
                    columns: 2
                    Measure {
                        id: topLeft; objectName: "topLeftControl"
                        caption: i18n("Top left")
                        from: -96; to: 96
                        onEdited: value => corners.sync(value)
                    }
                    Measure {
                        id: topRight; objectName: "topRightControl"
                        caption: i18n("Top right")
                        from: -96; to: 96
                        onEdited: value => corners.sync(value)
                    }
                    Measure {
                        id: bottomLeft; objectName: "bottomLeftControl"
                        caption: i18n("Bottom left")
                        from: -96; to: 96
                        onEdited: value => corners.sync(value)
                    }
                    Measure {
                        id: bottomRight; objectName: "bottomRightControl"
                        caption: i18n("Bottom right")
                        from: -96; to: 96
                        onEdited: value => corners.sync(value)
                    }
                }
                Controls.CheckBox {
                    id: linkCorners; objectName: "linkCornersControl"
                    Layout.alignment: Qt.AlignVCenter
                    text: i18n("Link corners")
                    onToggled: corners.sync(topLeft.value)
                }
            }
            Controls.Label { Layout.fillWidth: true; Layout.preferredWidth: Kirigami.Units.gridUnit * 22; wrapMode: Text.WordWrap; text: i18n("Negative corner radii curve outward along the dock.") }
            Controls.SpinBox {
                id: borderWidth; objectName: "borderWidthControl"; Kirigami.FormData.label: i18n("Border thickness (px):")
                from: 0; to: 12; editable: true
            }
            ColorSetting {
                id: outline; objectName: "outlineColorControl"; paletteSource: page.paletteSource
                Kirigami.FormData.label: i18n("Border color:")
                enabled: borderWidth.value > 0
                defaultColor: Kirigami.Theme.disabledTextColor
            }
            Controls.SpinBox {
                id: borderOpacity; objectName: "borderOpacityControl"; Kirigami.FormData.label: i18n("Border opacity (%):")
                from: 0; to: 100; editable: true
                enabled: borderWidth.value > 0
            }
            GridLayout {
                columns: 2
                Kirigami.FormData.label: i18n("Inner padding (px):")
                Measure {
                    id: horizontalPadding; objectName: "horizontalPaddingControl"
                    caption: i18n("Along the dock")
                    from: 0; to: 128
                }
                Measure {
                    id: verticalPadding; objectName: "verticalPaddingControl"
                    visible: !page.freeLayout
                    caption: i18n("Across the dock")
                    from: 0; to: 64
                }
            }
            Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Drop shadow") }
            ColorSetting {
                id: dockShadowColor; objectName: "dockShadowColorControl"; paletteSource: page.paletteSource; defaultColor: page.paletteSource.shadowColor
                Kirigami.FormData.label: i18n("Color:")
            }
            Controls.SpinBox {
                id: dockShadowStrength; objectName: "dockShadowStrengthControl"; from: 0; to: 100; editable: true
                Kirigami.FormData.label: i18n("Strength (%):")
            }
            Controls.SpinBox {
                id: dockShadowSize; objectName: "dockShadowSizeControl"; from: 0; to: 32; editable: true
                Kirigami.FormData.label: i18n("Size (px):")
            }
            RowLayout {
                Kirigami.FormData.label: i18n("Offset (px):")
                Measure { id: dockShadowX; objectName: "dockShadowXControl"; caption: "X"; from: -32; to: 32 }
                Measure { id: dockShadowY; objectName: "dockShadowYControl"; caption: "Y"; from: -32; to: 32 }
            }
            Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Hover glow") }
            Controls.CheckBox { id: glow; objectName: "glowControl"; text: i18n("Enable hover glow") }
            Controls.SpinBox {
                id: glowRadius; objectName: "glowRadiusControl"; visible: glow.checked
                Kirigami.FormData.label: i18n("Glow radius (px, 0 = automatic):")
                from: 0; to: 256; editable: true
            }
            Controls.SpinBox {
                id: glowIntensity; objectName: "glowIntensityControl"; visible: glow.checked
                Kirigami.FormData.label: i18n("Glow intensity (%):")
                from: 0; to: 200; editable: true
            }
            Controls.SpinBox {
                id: glowOpacity; objectName: "glowOpacityControl"; visible: glow.checked
                Kirigami.FormData.label: i18n("Glow opacity (%):")
                from: 0; to: 100; editable: true
            }
        }
    }
}
