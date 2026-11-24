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
        implicitWidth: Math.min(window.contentItem.width, Math.max(implicitFooterWidth, removalMessage.implicitWidth + leftPadding + rightPadding))
        parent: window.contentItem
        anchors.centerIn: parent
        modal: true
        title: i18n("Remove %1?", window.profiles ? window.profiles.labels[window.profiles.selectedIndex] || "" : "")
        standardButtons: Controls.Dialog.Ok | Controls.Dialog.Cancel
        contentItem: Controls.Label {
            id: removalMessage
            text: i18n("Its settings and pinned applications will be removed.")
            wrapMode: Text.WordWrap
        }
        onAccepted: if (!window.profiles.removeSelected()) window.profileError = i18n("Could not remove the dock.")
    }
    DockPalette { id: dockPalette }
    ApplicationChooser {
        id: applicationChooser
        parent: window.contentItem
        onChosen: url => {
            const list = launcherResolver.insert(dockSettings.values.launchers, [url], "");
            dockSettings.saveLaunchers(list);
        }
    }
    property QtObject selectedTasks: null
    function openSettings() {
        login.checked = login.saved = dockSettings.startsAtLogin();
        loginError.visible = false;
        const v = dockSettings.values;
        edge.currentIndex = v.edge;
        window.draftScreen = v.screen;
        window.profileError = "";
        spacing.value = v.spacing;
        alignment.currentIndex = v.dockAlignment;
        alignmentMargin.value = v.alignmentMargin;
        visibilityMode.currentIndex = v.visibilityMode;
        highlightPreview.checked = v.highlightPreviewWindow;
        windowPreviews.checked = v.showWindowPreviews;
        audioIndicator.checked = v.showAudioIndicator;
        muteOnClick.checked = v.muteOnClick;
        mediaControls.checked = v.showMediaControls;
        badges.checked = v.showBadges;
        progress.checked = v.showProgress;
        appearanceSettings.load(v);
        iconSettings.load(v);
        indicators.load(v);
        behaviorPage.load(v);
        visible = true;
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
            if (!dockSettings.apply(Object.assign({}, behaviorPage.values, indicators.previewConfiguration, appearanceSettings.draft(), iconSettings.draft(), {
                edge: edge.currentIndex,
                screen: window.draftScreen,
                spacing: spacing.value,
                highlightPreviewWindow: highlightPreview.checked,
                showWindowPreviews: windowPreviews.checked,
                showAudioIndicator: audioIndicator.checked,
                muteOnClick: muteOnClick.checked,
                showMediaControls: mediaControls.checked,
                showBadges: badges.checked,
                showProgress: progress.checked,
                dockAlignment: alignment.currentIndex,
                alignmentMargin: alignmentMargin.value,
                visibilityMode: visibilityMode.currentIndex
            }))) return;
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
    readonly property var sections: [
        {title: i18n("Position and visibility"), icon: "preferences-desktop-display"},
        {title: i18n("Appearance"), icon: "preferences-desktop-color"},
        {title: i18n("Icons and animations"), icon: "preferences-desktop-icons"},
        {title: i18n("Indicators"), icon: "view-statistics"},
        {title: i18n("Behavior"), icon: "input-mouse"},
        {title: i18n("Applications and sorting"), icon: "view-list-details"},
        {title: i18n("Modules"), icon: "preferences-plugin"}
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
                        SettingsForm {
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
                            Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Session") }
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
                AppearanceSettings {
                    id: appearanceSettings
                    paletteSource: dockPalette
                }
                IconSettings {
                    id: iconSettings
                    paletteSource: dockPalette
                    behavior: behaviorPage
                }
                IndicatorsSettings { id: indicators }
                Controls.ScrollView {
                    contentWidth: availableWidth
                    ColumnLayout {
                        width: parent.width
                        spacing: Kirigami.Units.largeSpacing
                        BehaviorSettings { id: behaviorPage; Layout.fillWidth: true }
                        SettingsForm {
                            Layout.fillWidth: true
                            Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Previews and media") }
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
                ApplicationsSettings {
                    tasks: window.selectedTasks
                    onAddRequested: applicationChooser.open()
                }
                ModulesSettings {
                    profile: dockSettings
                    catalog: typeof moduleCatalog === "undefined" ? ({}) : moduleCatalog
                }
            }
        }
    }
}
