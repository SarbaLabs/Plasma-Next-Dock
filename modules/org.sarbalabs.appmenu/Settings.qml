// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls as C
import QtQuick.Layouts
import org.kde.kirigami as K
import org.kde.config as Config
import org.kde.kcmutils as KCM
import "native" as Native
C.ApplicationWindow {
    id: page
    property var configuration: ({})
    signal edited(var changes)
    title: i18n("Applications menu")
    width: 560
    height: 600
    minimumWidth: 460
    minimumHeight: 420
    color: K.Theme.backgroundColor
    flags: Qt.Dialog
    Native.MenuTools { id: tools; onIconChosen: name => page.edited({icon:name}) }
    C.ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth
        K.FormLayout {
            width: parent.width
            RowLayout {
                K.FormData.label: i18n("Menu icon:")
                C.Button { icon.name: page.configuration.icon || "start-here-kde"; text: i18n("Choose an icon…"); onClicked: tools.chooseIcon(icon.name) }
                C.ToolButton { icon.name: "edit-undo"; text: i18n("Restore default"); onClicked: page.edited({icon:""}) }
            }
            C.ComboBox {
                K.FormData.label: i18n("Applications pane:")
                model: [i18n("Right"), i18n("Left")]
                currentIndex: page.configuration.contentLeft ? 1 : 0
                onActivated: index => page.edited({contentLeft:index === 1})
            }
            component Presentation: C.ComboBox { model: [i18n("List"),i18n("Grid")] }
            Presentation {
                K.FormData.label: i18n("Favorites:")
                currentIndex: page.configuration.favoritesGrid === false ? 0 : 1
                onActivated: index => page.edited({favoritesGrid: index === 1})
            }
            Presentation {
                K.FormData.label: i18n("Categories:")
                currentIndex: page.configuration.categoryGrid ? 1 : 0
                onActivated: index => page.edited({categoryGrid: index === 1})
            }
            C.ComboBox {
                K.FormData.label: i18n("Application labels:")
                model: [i18n("Name only"), i18n("Description only"), i18n("Name (description)"), i18n("Description (name)")]
                currentIndex: page.configuration.format ?? 0
                onActivated: index => page.edited({format:index})
            }
            C.CheckBox {
                text: i18n("Sort applications alphabetically")
                checked: !!page.configuration.alphabetical
                onClicked: page.edited({alphabetical:checked})
            }
            C.CheckBox {
                text: i18n("Switch sidebar categories on hover")
                checked: !!page.configuration.hoverCategories
                onClicked: page.edited({hoverCategories:checked})
            }
            C.Button {
                text: i18n("Configure search plugins…")
                icon.name: "configure"
                enabled: Config.KAuthorized.authorizeControlModule("kcm_plasmasearch")
                onClicked: KCM.KCMLauncher.openSystemSettings("kcm_plasmasearch")
            }
            RowLayout {
                K.FormData.label: i18n("Scroll speed:")
                C.Slider {
                    id: speed
                    Accessible.name: i18n("Scroll speed:")
                    from: 1
                    to: 10
                    stepSize: 1
                    snapMode: C.Slider.SnapAlways
                    value: page.configuration.wheelSpeed ?? 4
                    onMoved: page.edited({wheelSpeed: Math.round(value)})
                }
                C.Label { text: i18n("%1×", Math.round(speed.value)) }
            }
            component Dimension: C.SpinBox { editable: true; to: 2400 }
            RowLayout {
                K.FormData.label: i18n("Width × height (px):")
                Dimension { from: 420; value: page.configuration.width ?? 960; onValueModified: page.edited({width:value}) }
                Dimension { from: 300; value: page.configuration.height ?? 490; onValueModified: page.edited({height:value}) }
            }
            RowLayout {
                K.FormData.label: i18n("Corner radii (px):")
                GridLayout {
                    columns: 2
                    Repeater {
                        model: ["tl","tr","bl","br"]
                        C.SpinBox {
                            required property string modelData
                            from: -96; to: 96; editable: true
                            value: page.configuration[modelData] ?? 10
                            onValueModified: page.edited(linked.checked ? {tl:value,tr:value,bl:value,br:value} : {[modelData]:value})
                        }
                    }
                }
                C.CheckBox {
                    id: linked
                    text: i18n("Link corners")
                    checked: page.configuration.linked !== false
                    onClicked: {
                        const v = page.configuration.tl ?? 10;
                        page.edited(checked ? {linked:true,tl:v,tr:v,bl:v,br:v} : {linked:false});
                    }
                }
            }
        }
    }
}
