// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Item {
    id: page
    required property var profile
    required property var catalog
    property string draggedId: ""
    property int targetColumn: -1
    property int insertion: -1
    readonly property var keys: ["left", "disabled", "right"]
    readonly property var columns: {
        const zones = profile.values.moduleZones;
        const lists = keys.map(key => Array.from(zones[key] || []));
        const known = [].concat(...lists);
        lists[1].push(...Object.keys(catalog).filter(id => !known.includes(id)));
        return lists;
    }
    ModuleSettingsHost { id: settingsWindow; profile: page.profile }
    onProfileChanged: cancelDrag()
    function cancelDrag() { draggedId = ""; targetColumn = -1; insertion = -1; }
    function locate(point) {
        targetColumn = -1;
        for (let i = 0; i < panels.count; ++i) {
            const view = panels.itemAt(i).list;
            const local = view.mapFromItem(page, point.x, point.y);
            if (!view.contains(local)) continue;
            targetColumn = i;
            const y = local.y + view.contentY;
            const row = view.indexAt(1, y);
            const delegate = view.itemAtIndex(row);
            insertion = delegate ? row + Number(y >= delegate.y + delegate.height / 2) : view.count;
            return;
        }
    }
    function moveBlock(id, column, position) {
        const zones = {};
        for (let i = 0; i < keys.length; ++i) {
            const ids = columns[i].slice();
            const previous = ids.indexOf(id);
            if (previous >= 0) ids.splice(previous, 1);
            if (i === column) ids.splice(previous >= 0 && previous < position ? position - 1 : position, 0, id);
            zones[keys[i]] = ids;
        }
        profile.apply({moduleZones: zones});
    }
    RowLayout {
        anchors.fill: parent
        Repeater {
            id: panels
            model: [i18n("Left / Top"), i18n("Disabled"), i18n("Right / Bottom")]
            delegate: Controls.Frame {
                id: panel
                required property int index
                required property string modelData
                property alias list: list
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.fillHeight: true
                padding: 4
                background: Rectangle {
                    color: Kirigami.Theme.backgroundColor
                    border.color: Kirigami.Theme.disabledTextColor
                    radius: 4
                }
                ColumnLayout {
                    anchors.fill: parent
                    Controls.Label { Layout.alignment: Qt.AlignHCenter; text: panel.modelData; font.bold: true }
                    Kirigami.Separator { Layout.fillWidth: true }
                    ListView {
                        id: list
                        objectName: "moduleColumn" + panel.index
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        model: page.columns[panel.index]
                        Controls.ScrollBar.vertical: Controls.ScrollBar {}
                        delegate: Item {
                            id: card
                            required property int index
                            required property string modelData
                            width: list.width
                            height: Math.max(40, label.implicitHeight + 10)
                            RowLayout {
                                anchors.fill: parent
                                spacing: 2
                                Kirigami.Icon {
                                    Layout.preferredWidth: 18
                                    Layout.preferredHeight: 18
                                    source: "drag-handle-symbolic"
                                }
                                Controls.Label {
                                    id: label
                                    Layout.fillWidth: true
                                    text: page.catalog[card.modelData]?.name || card.modelData
                                    wrapMode: Text.Wrap
                                }
                                Controls.ToolButton {
                                    z: 2
                                    visible: !!page.catalog[card.modelData]?.settingsUrl
                                    icon.name: "configure"
                                    display: Controls.AbstractButton.IconOnly
                                    text: i18n("Configure module: %1…", label.text)
                                    Controls.ToolTip.text: text
                                    Controls.ToolTip.visible: hovered
                                    onClicked: settingsWindow.open(page.catalog[card.modelData])
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                anchors.rightMargin: page.catalog[card.modelData]?.settingsUrl ? 40 : 0
                                cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                                preventStealing: true
                                property point start
                                onPressed: mouse => { start = mapToItem(page, mouse.x, mouse.y); }
                                onPositionChanged: mouse => {
                                    if (!pressed) return;
                                    const p = mapToItem(page, mouse.x, mouse.y);
                                    if (!page.draggedId && Math.hypot(p.x-start.x, p.y-start.y) < Qt.styleHints.startDragDistance) return;
                                    page.draggedId = card.modelData;
                                    ghost.x = p.x + 8; ghost.y = p.y + 8;
                                    page.locate(p);
                                }
                                onReleased: mouse => {
                                    if (!page.draggedId) return;
                                    page.locate(mapToItem(page, mouse.x, mouse.y));
                                    const id = page.draggedId, column = page.targetColumn, at = page.insertion;
                                    page.cancelDrag();
                                    if (column >= 0) page.moveBlock(id, column, at);
                                }
                                onCanceled: page.cancelDrag()
                            }
                            opacity: page.draggedId === modelData ? 0.5 : 1
                        }
                        Rectangle {
                            visible: page.targetColumn === panel.index
                            width: parent.width; height: 2
                            y: (list.itemAtIndex(page.insertion)?.y ?? list.contentHeight) - list.contentY
                            color: Kirigami.Theme.highlightColor
                        }
                    }
                }
            }
        }
    }
    Controls.Label {
        id: ghost
        visible: page.draggedId.length > 0
        text: page.catalog[page.draggedId]?.name || page.draggedId
        padding: 5
        background: Rectangle { color: Kirigami.Theme.backgroundColor; border.color: Kirigami.Theme.highlightColor }
    }
}
