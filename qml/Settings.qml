// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Controls.ApplicationWindow {
    id: window
    objectName: "settingsWindow"
    title: i18n("Configure Plasma Next Dock")
    width: Math.min(1060, Screen.desktopAvailableWidth); height: Math.min(790, Screen.desktopAvailableHeight)
    minimumWidth: 460; minimumHeight: 400
    visible: false
    readonly property var profiles: typeof dockProfiles === "undefined" ? null : dockProfiles
    property string profileError: ""
    property string draftScreen: ""
    readonly property var screenNames: outputNames.indexOf(draftScreen) < 0 ? outputNames.concat([draftScreen]) : outputNames
    Controls.Dialog {
        id: confirmRemoval
        parent: window.contentItem
        anchors.centerIn: parent
        modal: true
        title: i18n("Remove %1?", window.profiles ? window.profiles.labels[window.profiles.selectedIndex] || "" : "")
        standardButtons: Controls.Dialog.Ok | Controls.Dialog.Cancel
        Controls.Label { text: i18n("Its settings and pinned applications will be removed.") }
        onAccepted: if (!window.profiles.removeSelected()) window.profileError = i18n("Could not remove the dock.")
    }
    DockPalette { id: dockPalette }
    ApplicationChooser {
        id: applicationChooser
        parent: window.contentItem
        onChosen: url => {
            const list = launcherResolver.insert(dockSettings.values.launchers, [url], "");
            if (dockSettings.saveLaunchers(list)) window.launcherError = "";
        }
    }
    property string launcherError: ""
    function openSettings() {
        login.checked = login.saved = dockSettings.startsAtLogin();
        loginError.visible = false;
        const v = dockSettings.values;
        edge.currentIndex = v.edge;
        window.draftScreen = v.screen;
        window.profileError = "";
        iconSize.value = v.iconSize; zoom.value = Math.round(v.zoom * 100);
        blastRadius.value = v.blastRadius; hoverLift.value = v.hoverLift;
        iconColors.currentIndex = v.grayscaleIcons ? 1 : 0;
        tintIcons.checked = v.tintIcons;
        iconTint.role = v.iconTintRole; iconTint.fixedColor = v.iconTintColor;
        tintSaturation.value = v.iconTintSaturation;
        spacing.value = v.spacing;
        glow.checked = v.glow;
        glowRadius.value = v.glowRadius; glowIntensity.value = v.glowIntensity; glowOpacity.value = v.glowOpacity;
        alignment.currentIndex = v.dockAlignment; alignmentMargin.value = v.alignmentMargin; visibilityMode.currentIndex = v.visibilityMode;
        backgroundType.currentIndex = backgroundType.modeIds.indexOf(v.backgroundType);
        systemBlur.checked = v.systemBlur;
        midpoint.value = v.gradientMidpoint;
        glassOpacity.value = Math.round(v.glassOpacity * 100);
        backgroundOpacity.value = Math.round(v.backgroundOpacity * 100);
        borderWidth.value = v.borderWidth;
        borderOpacity.value = Math.round(v.borderOpacity * 100);
        topOpacity.value = Math.round(v.gradientTopOpacity * 100);
        bottomOpacity.value = Math.round(v.gradientBottomOpacity * 100);
        fill.role = v.backgroundRole; fill.fixedColor = v.backgroundColor;
        upper.role = v.gradientTopRole; upper.fixedColor = v.gradientTopColor;
        lower.role = v.gradientBottomRole; lower.fixedColor = v.gradientBottomColor;
        outline.role = v.borderRole; outline.fixedColor = v.borderColor;
        topLeft.value = v.topLeftRadius;
        topRight.value = v.topRightRadius;
        bottomLeft.value = v.bottomLeftRadius;
        bottomRight.value = v.bottomRightRadius;
        iconSpacing.value = v.iconSpacing; horizontalPadding.value = v.horizontalPadding; verticalPadding.value = v.verticalPadding;
        highlightPreview.checked = v.highlightPreviewWindow;
        windowPreviews.checked = v.showWindowPreviews; audioIndicator.checked = v.showAudioIndicator;
        muteOnClick.checked = v.muteOnClick; mediaControls.checked = v.showMediaControls;
        badges.checked = v.showBadges; progress.checked = v.showProgress;
        iconHover.checked = v.iconHoverHighlight;
        indicators.load(v);
        behavior.load(v);
        visible = true;
    }
    function moveLauncher(index, delta) {
        const list = dockSettings.values.launchers.slice();
        const target = index + delta;
        if (target < 0 || target >= list.length) return;
        const entry = list.splice(index, 1)[0]; list.splice(target, 0, entry);
        dockSettings.saveLaunchers(list);
    }
    footer: Controls.DialogButtonBox {
        objectName: "settingsButtons"
        standardButtons: Controls.DialogButtonBox.Apply | Controls.DialogButtonBox.Close
        onApplied: {
            if (window.profiles && !window.profiles.positionAvailable(window.draftScreen, edge.currentIndex)) {
                window.profileError = i18n("Another dock uses this screen edge. Choose a different edge or screen.");
                return;
            }
            window.profileError = "";
            if (!dockSettings.apply(Object.assign({}, behavior.values, indicators.previewConfiguration, {edge: edge.currentIndex, screen: window.draftScreen,
            iconHoverHighlight: iconHover.checked,
            grayscaleIcons: iconColors.currentIndex === 1, tintIcons: tintIcons.checked,
            iconTintRole: iconTint.role, iconTintColor: iconTint.fixedColor.toString(), iconTintSaturation: tintSaturation.value,
            iconSize: iconSize.value, zoom: zoom.value / 100, spacing: spacing.value,
            backgroundType: backgroundType.mode, systemBlur: systemBlur.checked, gradientMidpoint: midpoint.value, glassOpacity: glassOpacity.value / 100, backgroundOpacity: backgroundOpacity.value / 100,
            borderWidth: borderWidth.value, borderRole: outline.role, borderColor: outline.fixedColor.toString(), borderOpacity: borderOpacity.value / 100,
            backgroundRole: fill.role, backgroundColor: fill.fixedColor.toString(),
            gradientTopRole: upper.role, gradientTopColor: upper.fixedColor.toString(), gradientTopOpacity: topOpacity.value / 100,
            gradientBottomRole: lower.role, gradientBottomColor: lower.fixedColor.toString(), gradientBottomOpacity: bottomOpacity.value / 100,
            iconSpacing: iconSpacing.value, horizontalPadding: horizontalPadding.value, verticalPadding: verticalPadding.value,
            highlightPreviewWindow: highlightPreview.checked, showWindowPreviews: windowPreviews.checked, showAudioIndicator: audioIndicator.checked, muteOnClick: muteOnClick.checked,
            showMediaControls: mediaControls.checked, showBadges: badges.checked, showProgress: progress.checked,
            blastRadius: blastRadius.value, hoverLift: hoverLift.value,
            topLeftRadius: topLeft.value, topRightRadius: topRight.value, bottomLeftRadius: bottomLeft.value, bottomRightRadius: bottomRight.value, glow: glow.checked,
            glowRadius: glowRadius.value, glowIntensity: glowIntensity.value, glowOpacity: glowOpacity.value,
            dockAlignment: alignment.currentIndex, alignmentMargin: alignmentMargin.value, visibilityMode: visibilityMode.currentIndex}))) return;
            if (login.checked !== login.saved) {
                loginError.visible = !dockSettings.setStartAtLogin(login.checked);
                login.checked = login.saved = dockSettings.startsAtLogin();
            }
        }
        onRejected: window.close()
    }
    header: ColumnLayout {
        spacing: 0
        RowLayout {
            visible: !!window.profiles
            Layout.fillWidth: true
            Layout.margins: 12
            Kirigami.Icon { source: "preferences-desktop-display"; implicitWidth: 22; implicitHeight: 22 }
            Controls.Label { text: i18n("Selected dock:") }
            Controls.ComboBox {
                objectName: "dockSelector"
                Layout.fillWidth: true
                model: window.profiles ? window.profiles.labels.map((label, index) => {
                    const output = window.profiles.profileAt(index)?.values.screen || primaryOutput;
                    return label + " — " + screen.fullLabel(output);
                }) : []
                currentIndex: window.profiles ? window.profiles.selectedIndex : -1
                Accessible.name: i18n("Selected dock:")
                onActivated: index => window.profiles.select(index)
            }
            Controls.ToolButton {
                icon.name: "list-add"
                display: Controls.AbstractButton.IconOnly
                Controls.ToolTip.visible: hovered
                Controls.ToolTip.text: text
                text: i18n("Add dock")
                onClicked: if (!window.profiles.add()) window.profileError = i18n("Could not add a dock. Check for a free screen edge and a writable configuration file.")
            }
            Controls.ToolButton {
                icon.name: "edit-delete"
                display: Controls.AbstractButton.IconOnly
                Controls.ToolTip.visible: hovered
                Controls.ToolTip.text: text
                text: i18n("Remove dock")
                enabled: !!window.profiles && window.profiles.labels.length > 1
                onClicked: confirmRemoval.open()
            }
        }
        Controls.Label {
            visible: text.length > 0
            text: window.profileError
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            color: Kirigami.Theme.negativeTextColor
        }
    }
    component Measure: ColumnLayout {
        property string caption
        property alias value: field.value
        property alias from: field.from
        property alias to: field.to
        Controls.Label { text: parent.caption }
        Controls.SpinBox { id: field; editable: true; Accessible.name: parent.caption }
    }
    readonly property var sections: [
        {title: i18n("Position and visibility"), icon: "preferences-desktop-display"},
        {title: i18n("Appearance"), icon: "preferences-desktop-color"},
        {title: i18n("Icons and animations"), icon: "preferences-desktop-icons"},
        {title: i18n("Indicators"), icon: "view-statistics"},
        {title: i18n("Behavior"), icon: "input-mouse"},
        {title: i18n("Pinned applications"), icon: "view-list-details"}
    ]
    RowLayout {
        anchors.fill: parent
        spacing: 0
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: window.width < 760 ? 52 : 220
            color: Kirigami.Theme.alternateBackgroundColor
            ListView {
                id: navigation
                objectName: "settingsNavigation"
                anchors.fill: parent
                anchors.margins: 4
                model: window.sections
                currentIndex: 0
                keyNavigationEnabled: true
                delegate: Controls.ItemDelegate {
                    required property int index
                    required property var modelData
                    width: ListView.view.width
                    text: modelData.title
                    icon.name: modelData.icon
                    highlighted: ListView.isCurrentItem
                    display: window.width < 760 ? Controls.AbstractButton.IconOnly : Controls.AbstractButton.TextBesideIcon
                    Controls.ToolTip.visible: hovered && window.width < 760
                    Controls.ToolTip.text: text
                    onClicked: navigation.currentIndex = index
                }
            }
        }
        Kirigami.Separator { Layout.fillHeight: true }
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: Kirigami.Units.largeSpacing
            Kirigami.Heading {
                Layout.leftMargin: Kirigami.Units.smallSpacing
                level: 2
                text: window.sections[navigation.currentIndex]?.title ?? ""
            }
            StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: navigation.currentIndex
                Controls.ScrollView {
                    contentWidth: availableWidth
                    ColumnLayout {
                        width: parent.width
                        spacing: Kirigami.Units.largeSpacing
                        Kirigami.FormLayout {
                            Layout.fillWidth: true
                            Controls.ComboBox {
                                id: screen
                                objectName: "screenControl"
                                // Avoid style content-item/implicit-width feedback in Breeze.
                                implicitWidth: Kirigami.Units.gridUnit * 16
                                Kirigami.FormData.label: i18n("Screen:")
                                function fullLabel(name) {
                                    if (!name) return i18n("Primary screen");
                                    if (outputNames.indexOf(name) < 0) return i18n("%1 (disconnected)", name);
                                    const description = outputDescriptions[name];
                                    return description ? i18n("%1: %2", name, description) : name;
                                }
                                FontMetrics { id: screenMetrics; font: screen.font }
                                // Leave room for the native style's dropdown arrow and margins.
                                readonly property real labelWidth: Math.max(0, width - 2 * Kirigami.Units.gridUnit)
                                model: window.screenNames.map(name => screenMetrics.elidedText(
                                    fullLabel(name), Qt.ElideRight, labelWidth))
                                Controls.ToolTip.text: fullLabel(window.draftScreen)
                                Controls.ToolTip.visible: hovered && displayText !== Controls.ToolTip.text && !popup.visible
                                currentIndex: window.screenNames.indexOf(window.draftScreen)
                                onActivated: index => window.draftScreen = window.screenNames[index]
                            }
                            Controls.ComboBox {
                                id: edge
                                objectName: "edgeControl"
                                implicitWidth: Kirigami.Units.gridUnit * 16
                                Kirigami.FormData.label: i18n("Edge:")
                                model: [i18n("Bottom"), i18n("Top"), i18n("Left"), i18n("Right")]
                            }
                            Controls.ComboBox {
                                id: alignment; objectName: "dockAlignmentControl"
                                Kirigami.FormData.label: i18n("Dock alignment:")
                                textRole: edge.currentIndex < 2 ? "horizontal" : "vertical"
                                model: [{horizontal: i18n("Left"), vertical: i18n("Top")},
                                        {horizontal: i18n("Centered"), vertical: i18n("Centered")},
                                        {horizontal: i18n("Right"), vertical: i18n("Bottom")}]
                            }
                            GridLayout {
                                columns: 2
                                Kirigami.FormData.label: i18n("Outer margins (px):")
                                Measure {
                                    id: spacing; objectName: "spacingControl"
                                    caption: i18n("Screen edge")
                                    from: 0; to: 128
                                }
                                Measure {
                                    id: alignmentMargin; objectName: "alignmentMarginControl"
                                    caption: edge.currentIndex < 2 ? (alignment.currentIndex === 0 ? i18n("Left") : i18n("Right"))
                                        : (alignment.currentIndex === 0 ? i18n("Top") : i18n("Bottom"))
                                    from: 0; to: 512
                                    visible: alignment.currentIndex !== 1
                                }
                            }
                            Controls.ComboBox {
                                id: visibilityMode; objectName: "visibilityModeControl"
                                Kirigami.FormData.label: i18n("Visibility:")
                                model: [i18n("Always visible"), i18n("Auto hide"), i18n("Dodge windows"), i18n("Windows go below")]
                            }
                            Controls.Label { text: i18n("Session"); font.bold: true; Kirigami.FormData.isSection: true }
                            Controls.CheckBox {
                                id: login
                                objectName: "startAtLoginControl"
                                property bool saved: false
                                Kirigami.FormData.label: i18n("All docks:")
                                enabled: dockSettings.loginAvailable
                                text: i18n("Start Plasma Next Dock at login")
                            }
                            Controls.Label {
                                id: loginError
                                visible: false
                                Layout.fillWidth: true
                                wrapMode: Text.WordWrap
                                color: Kirigami.Theme.negativeTextColor
                                text: i18n("Could not update the login entry. Check the dock installation and your autostart directory.")
                            }
                        }
                    }
                }
                Controls.ScrollView {
                    contentWidth: availableWidth
                    ColumnLayout {
                        width: parent.width
                        spacing: Kirigami.Units.largeSpacing
                        Kirigami.FormLayout {
                            Layout.fillWidth: true
                            Controls.ComboBox {
                                id: backgroundType; objectName: "backgroundTypeControl"
                                implicitWidth: Kirigami.Units.gridUnit * 16
                                Kirigami.FormData.label: i18n("Background:")
                                readonly property var modeIds: [0, 4, 5]
                                readonly property int mode: modeIds[currentIndex] ?? 0
                                model: [i18n("Solid"), i18n("Liquid Glass"), i18n("Gradient")]
                            }
                            ColorSetting {
                                id: fill; objectName: "fillColorControl"; paletteSource: dockPalette
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
                                id: upper; objectName: "upperColorControl"; paletteSource: dockPalette
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
                                id: lower; objectName: "lowerColorControl"; paletteSource: dockPalette
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
                            Controls.Label { text: i18n("Corners and border"); font.bold: true; Kirigami.FormData.isSection: true }
                            GridLayout {
                                columns: 2
                                Kirigami.FormData.label: i18n("Corner radii (px):")
                                Measure {
                                    id: topLeft; objectName: "topLeftControl"
                                    caption: i18n("Top left")
                                    from: -96; to: 96
                                }
                                Measure {
                                    id: topRight; objectName: "topRightControl"
                                    caption: i18n("Top right")
                                    from: -96; to: 96
                                }
                                Measure {
                                    id: bottomLeft; objectName: "bottomLeftControl"
                                    caption: i18n("Bottom left")
                                    from: -96; to: 96
                                }
                                Measure {
                                    id: bottomRight; objectName: "bottomRightControl"
                                    caption: i18n("Bottom right")
                                    from: -96; to: 96
                                }
                            }
                            Controls.Label { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: i18n("Negative corner radii curve outward along the dock.") }
                            Controls.SpinBox {
                                id: borderWidth; objectName: "borderWidthControl"; Kirigami.FormData.label: i18n("Border thickness (px):")
                                from: 0; to: 12; editable: true
                            }
                            ColorSetting {
                                id: outline; objectName: "outlineColorControl"; paletteSource: dockPalette
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
                                    caption: i18n("Across the dock")
                                    from: 0; to: 64
                                }
                            }
                            Controls.Label { text: i18n("Hover glow"); font.bold: true; Kirigami.FormData.isSection: true }
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
                Controls.ScrollView {
                    contentWidth: availableWidth
                    ColumnLayout {
                        width: parent.width
                        spacing: Kirigami.Units.largeSpacing
                        Kirigami.FormLayout {
                            Layout.fillWidth: true
                            Controls.SpinBox { id: iconSize; objectName: "iconSizeControl"; Kirigami.FormData.label: i18n("Icon size (px):"); from: 24; to: 96; editable: true }
                            Controls.SpinBox { id: iconSpacing; objectName: "iconSpacingControl"; Kirigami.FormData.label: i18n("Space between icons (px):"); from: 0; to: 64; editable: true }
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
                                id: iconTint; objectName: "iconTintControl"; paletteSource: dockPalette
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
                            Controls.Label { text: i18n("Pointer effects"); font.bold: true; Kirigami.FormData.isSection: true }
                            Controls.CheckBox { id: iconHover; text: i18n("Highlight icons on hover") }
                            Controls.SpinBox { id: zoom; objectName: "zoomControl"; Kirigami.FormData.label: i18n("Magnification (%):"); from: 100; to: 250; stepSize: 5; editable: true }
                            Controls.SpinBox { id: blastRadius; objectName: "blastRadiusControl"; Kirigami.FormData.label: i18n("Blast radius (neighbor icons):"); from: 0; to: 8; editable: true }
                            Controls.SpinBox { id: hoverLift; objectName: "hoverLiftControl"; Kirigami.FormData.label: i18n("Hover lift (px):"); from: 0; to: 64; editable: true }
                            Controls.Label { text: i18n("Icon bounce"); font.bold: true; Kirigami.FormData.isSection: true }
                            Controls.CheckBox { objectName: "bounceEnabledControl"; text: i18n("Enable icon bounce"); checked: behavior.values.bounceEnabled === true; onToggled: behavior.change("bounceEnabled", checked) }
                            Controls.CheckBox { objectName: "bounceOnLaunchControl"; text: i18n("Bounce when launching an application"); enabled: behavior.values.bounceEnabled === true; checked: behavior.values.bounceOnLaunch === true; onToggled: behavior.change("bounceOnLaunch", checked) }
                            Controls.CheckBox { objectName: "bounceOnAttentionControl"; text: i18n("Bounce when an application requests attention"); enabled: behavior.values.bounceEnabled === true; checked: behavior.values.bounceOnAttention === true; onToggled: behavior.change("bounceOnAttention", checked) }
                            Controls.SpinBox { objectName: "bounceHeightControl"; Kirigami.FormData.label: i18n("Bounce height (px, 0 = automatic):"); enabled: behavior.values.bounceEnabled === true; from: 0; to: 64; value: behavior.values.bounceHeight || 0; editable: true; onValueModified: behavior.change("bounceHeight", value) }
                            Controls.SpinBox { objectName: "bounceSpeedControl"; Kirigami.FormData.label: i18n("Bounce speed (%):"); enabled: behavior.values.bounceEnabled === true; from: 50; to: 200; stepSize: 10; value: behavior.values.bounceSpeed || 100; editable: true; onValueModified: behavior.change("bounceSpeed", value) }
                            Controls.SpinBox { objectName: "bounceCountControl"; Kirigami.FormData.label: i18n("Launch and test repetitions:"); enabled: behavior.values.bounceEnabled === true; from: 1; to: 5; value: behavior.values.bounceCount || 3; editable: true; onValueModified: behavior.change("bounceCount", value) }
                            Controls.Label { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: i18n("Attention repeats until cleared. Bounce pauses while the dock is hidden, during dragging or while previews are open. Use the application's context menu to test it.") }
                        }
                    }
                }
                IndicatorsSettings { id: indicators }
                Controls.ScrollView {
                    contentWidth: availableWidth
                    ColumnLayout {
                        width: parent.width
                        spacing: Kirigami.Units.largeSpacing
                        BehaviorSettings { id: behavior; Layout.fillWidth: true }
                        Kirigami.FormLayout {
                            Layout.fillWidth: true
                            Controls.Label { text: i18n("Previews and media"); font.bold: true; Kirigami.FormData.isSection: true }
                            Controls.CheckBox { id: windowPreviews; objectName: "windowPreviewsControl"; text: i18n("Show window previews on hover") }
                            Controls.CheckBox {
                                id: highlightPreview
                                objectName: "highlightPreviewControl"
                                text: i18n("Highlight the window on the desktop when hovering over its preview")
                            }
                            Controls.CheckBox { id: audioIndicator; objectName: "audioIndicatorControl"; text: i18n("Show application audio indicator") }
                            Controls.CheckBox { id: muteOnClick; objectName: "muteOnClickControl"; text: i18n("Click audio indicator to mute"); enabled: audioIndicator.checked }
                            Controls.CheckBox { id: mediaControls; objectName: "mediaControlsControl"; text: i18n("Show media and volume controls in previews") }
                            Controls.CheckBox { id: badges; objectName: "badgesControl"; text: i18n("Show application counters") }
                            Controls.CheckBox { id: progress; objectName: "progressControl"; text: i18n("Show application progress") }
                        }
                    }
                }
                Controls.ScrollView {
                    contentWidth: availableWidth
                    ColumnLayout {
                        width: parent.width
                        spacing: Kirigami.Units.largeSpacing
                        Controls.Label {
                            Layout.fillWidth: true; Layout.leftMargin: 16; Layout.rightMargin: 16
                            text: i18n("Pin running applications from the dock's right-click menu. Changes to this list are saved immediately.")
                            wrapMode: Text.WordWrap
                        }
                        Repeater {
                            model: dockSettings.values.launchers
                            delegate: RowLayout {
                                required property int index
                                required property string modelData
                                Layout.fillWidth: true; Layout.leftMargin: 16; Layout.rightMargin: 16
                                Controls.Label { text: modelData; elide: Text.ElideMiddle; Layout.fillWidth: true }
                                Controls.ToolButton { text: i18n("Up"); enabled: index > 0; onClicked: window.moveLauncher(index, -1) }
                                Controls.ToolButton { text: i18n("Down"); enabled: index + 1 < dockSettings.values.launchers.length; onClicked: window.moveLauncher(index, 1) }
                                Controls.ToolButton {
                                    text: i18n("Remove")
                                    onClicked: {
                                        const list = dockSettings.values.launchers.slice(); list.splice(index, 1);
                                        dockSettings.saveLaunchers(list);
                                    }
                                }
                            }
                        }
                        Controls.Button {
                            Layout.leftMargin: 16
                            text: i18n("Add an application…")
                            onClicked: applicationChooser.open()
                        }
                        Controls.Label {
                            Layout.fillWidth: true; Layout.margins: 16
                            visible: text.length > 0
                            text: dockSettings.error || window.launcherError
                            color: Kirigami.Theme.negativeTextColor
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }
        }
    }
}
