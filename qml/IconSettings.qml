// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Controls.ScrollView {
    id: page
    required property QtObject paletteSource
    required property QtObject behavior

    function load(v) {
        iconSize.value = v.iconSize;
        zoom.value = Math.round(v.zoom * 100);
        hoverSpeed.value = 140 - (v.hoverDuration ?? 90);
        blastRadius.value = v.blastRadius;
        hoverLift.value = v.hoverLift;
        iconColors.currentIndex = v.grayscaleIcons ? 1 : 0;
        tintIcons.checked = v.tintIcons;
        iconTint.role = v.iconTintRole;
        iconTint.fixedColor = v.iconTintColor;
        tintSaturation.value = v.iconTintSaturation;
        iconShadowX.value = v.iconShadowX;
        iconShadowY.value = v.iconShadowY;
        iconShadowColor.role = v.iconShadowRole;
        iconShadowColor.fixedColor = v.iconShadowColor;
        iconShadowStrength.value = v.iconShadowStrength;
        iconShadowSize.value = v.iconShadowSize;
        iconSpacing.value = v.iconSpacing;
        iconHover.checked = v.iconHoverHighlight;
    }

    // Return only this page's keys so applying a draft preserves unrelated profile changes.
    function draft() {
        return {
            iconHoverHighlight: iconHover.checked,
            grayscaleIcons: iconColors.currentIndex === 1,
            tintIcons: tintIcons.checked,
            iconTintRole: iconTint.role,
            iconTintColor: iconTint.fixedColor.toString(),
            iconTintSaturation: tintSaturation.value,
            iconSize: iconSize.value,
            zoom: zoom.value / 100,
            iconShadowX: iconShadowX.value,
            iconShadowY: iconShadowY.value,
            iconShadowRole: iconShadowColor.role,
            iconShadowColor: iconShadowColor.fixedColor.toString(),
            iconShadowStrength: iconShadowStrength.value,
            iconShadowSize: iconShadowSize.value,
            iconSpacing: iconSpacing.value,
            hoverDuration: 140 - hoverSpeed.value,
            blastRadius: blastRadius.value,
            hoverLift: hoverLift.value
        };
    }

    contentWidth: availableWidth
    ColumnLayout {
        width: parent.width
        spacing: Kirigami.Units.largeSpacing
        SettingsForm {
            Layout.fillWidth: true
            Controls.SpinBox { id: iconSize; objectName: "iconSizeControl"; Kirigami.FormData.label: i18n("Icon size (px):"); from: 24; to: 96; editable: true }
            Controls.SpinBox { id: iconSpacing; objectName: "iconSpacingControl"; Kirigami.FormData.label: i18n("Space between icons (px):"); from: 0; to: 64; editable: true }
            RowLayout {
                Measure {
                    id: zoom; objectName: "zoomControl"
                    caption: i18n("Magnification (%):")
                    from: 100; to: 250; stepSize: 5
                }
                Measure {
                    id: hoverLift; objectName: "hoverLiftControl"
                    caption: i18n("Hover lift (px):")
                    from: 0; to: 64
                }
            }
            Controls.SpinBox { id: blastRadius; objectName: "blastRadiusControl"; Kirigami.FormData.label: i18n("Blast radius (neighbor icons):"); from: 0; to: 8; editable: true }
            Controls.ComboBox {
                id: iconColors; objectName: "iconColorsControl"
                Kirigami.FormData.label: i18n("Icon colors:")
                model: [i18n("Original colors"), i18n("Grayscale")]
            }
            Controls.CheckBox {
                id: tintIcons; objectName: "tintIconsControl"
                visible: iconColors.currentIndex === 1
                text: i18n("Tint grayscale icons")
            }
            ColorSetting {
                id: iconTint; objectName: "iconTintControl"; paletteSource: page.paletteSource
                visible: tintIcons.visible && tintIcons.checked
                defaultColor: Kirigami.Theme.highlightColor
                Kirigami.FormData.label: i18n("Icon tint:")
            }
            Controls.SpinBox {
                id: tintSaturation; objectName: "iconTintSaturationControl"
                visible: iconTint.visible
                Kirigami.FormData.label: i18n("Tint saturation (%):")
                from: 0; to: 100; editable: true
            }
            Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Drop shadow") }
            ColorSetting {
                id: iconShadowColor; objectName: "iconShadowColorControl"; paletteSource: page.paletteSource; defaultColor: page.paletteSource.shadowColor
                Kirigami.FormData.label: i18n("Color:")
            }
            Controls.SpinBox {
                id: iconShadowStrength; objectName: "iconShadowStrengthControl"; from: 0; to: 100; editable: true
                Kirigami.FormData.label: i18n("Strength (%):")
            }
            Controls.SpinBox {
                id: iconShadowSize; objectName: "iconShadowSizeControl"; from: 0; to: 32; editable: true
                Kirigami.FormData.label: i18n("Size (px):")
            }
            RowLayout {
                Kirigami.FormData.label: i18n("Offset (px):")
                Measure { id: iconShadowX; objectName: "iconShadowXControl"; caption: "X"; from: -32; to: 32 }
                Measure { id: iconShadowY; objectName: "iconShadowYControl"; caption: "Y"; from: -32; to: 32 }
            }
            Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Pointer effects") }
            Controls.CheckBox { id: iconHover; text: i18n("Highlight icons on hover") }
            Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Icon bounce") }
            Controls.CheckBox { objectName: "bounceEnabledControl"; text: i18n("Enable icon bounce"); checked: page.behavior.values.bounceEnabled === true; onToggled: page.behavior.change("bounceEnabled", checked) }
            Controls.CheckBox { objectName: "bounceOnLaunchControl"; text: i18n("Bounce when launching an application"); enabled: page.behavior.values.bounceEnabled === true; checked: page.behavior.values.bounceOnLaunch === true; onToggled: page.behavior.change("bounceOnLaunch", checked) }
            Controls.CheckBox { objectName: "bounceOnAttentionControl"; text: i18n("Bounce when an application requests attention"); enabled: page.behavior.values.bounceEnabled === true; checked: page.behavior.values.bounceOnAttention === true; onToggled: page.behavior.change("bounceOnAttention", checked) }
            Controls.SpinBox { objectName: "bounceHeightControl"; Kirigami.FormData.label: i18n("Bounce height (px, 0 = automatic):"); enabled: page.behavior.values.bounceEnabled === true; from: 0; to: 64; value: page.behavior.values.bounceHeight || 0; editable: true; onValueModified: page.behavior.change("bounceHeight", value) }
            Controls.SpinBox { objectName: "bounceSpeedControl"; Kirigami.FormData.label: i18n("Bounce speed (%):"); enabled: page.behavior.values.bounceEnabled === true; from: 50; to: 200; stepSize: 10; value: page.behavior.values.bounceSpeed || 100; editable: true; onValueModified: page.behavior.change("bounceSpeed", value) }
            Controls.SpinBox { objectName: "bounceCountControl"; Kirigami.FormData.label: i18n("Launch and test repetitions:"); enabled: page.behavior.values.bounceEnabled === true; from: 1; to: 5; value: page.behavior.values.bounceCount || 3; editable: true; onValueModified: page.behavior.change("bounceCount", value) }
            Controls.Label { Layout.fillWidth: true; Layout.preferredWidth: Kirigami.Units.gridUnit * 22; wrapMode: Text.WordWrap; text: i18n("Attention repeats until cleared. Bounce pauses while the dock is hidden, during dragging or while previews are open. Use the application's context menu to test it.") }
            Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Magnification animation") }
            RowLayout {
                Kirigami.FormData.label: i18n("Hover animation speed:")
                Controls.Label { text: i18n("Slow") }
                Controls.Slider {
                    id: hoverSpeed
                    objectName: "hoverSpeedControl"
                    Accessible.name: i18n("Hover animation speed:")
                    from: 0; to: 130; stepSize: 5
                    snapMode: Controls.Slider.SnapAlways
                }
                Controls.Label { text: i18n("Very fast") }
            }
        }
    }
}
