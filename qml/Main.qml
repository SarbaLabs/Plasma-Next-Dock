// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import "code/CapsuleGeometry.js" as Geometry

Item {
    id: root
    readonly property bool vertical: dockOptions.edge >= 2
    readonly property real base: dockOptions.iconSize
    readonly property real maximum: base * dockOptions.zoom
    readonly property real depth: maximum + 32
    readonly property real length: Math.min((vertical ? outputSize.height : outputSize.width) - 16,
        Math.max(200, repeater.count * (maximum + 12) + 32))
    width: vertical ? depth : length
    height: vertical ? length : depth
    property real pointerIndex: -10
    property bool hovering: pointer.hovered
    property color applicationColor: Kirigami.Theme.highlightColor
    readonly property real barThickness: base + 20
    readonly property real barLength: Math.min(length, Math.max(160, taskRow.width + 24))

    function updatePointer(position) {
        const coordinate = vertical ? position.y : position.x;
        let nearest = -1;
        let distance = Infinity;
        let fraction = 0;
        for (let i = 0; i < repeater.count; ++i) {
            const slot = repeater.itemAt(i);
            if (!slot) continue;
            const center = slot.mapToItem(root, slot.width / 2, slot.height / 2);
            const delta = coordinate - (vertical ? center.y : center.x);
            if (Math.abs(delta) < distance) {
                distance = Math.abs(delta);
                nearest = i;
                fraction = delta / (slot.width + taskRow.spacing);
            }
        }
        pointerIndex = nearest < 0 ? -10 : nearest + fraction;
    }
    function syncGeometry() {
        let icons = [];
        for (let i = 0; i < repeater.count; ++i) {
            const slot = repeater.itemAt(i);
            if (!slot) continue;
            const p = slot.iconItem.mapToItem(root, 0, 0);
            icons.push(Qt.rect(p.x, p.y, slot.iconItem.width, slot.iconItem.height));
        }
        dockController.setGeometry(Qt.rect(bar.x, bar.y, bar.width, bar.height), bar.radius, icons, dockOptions.edge);
    }
    function queueGeometry() { Qt.callLater(syncGeometry); }
    onWidthChanged: queueGeometry()
    onHeightChanged: queueGeometry()
    Component.onCompleted: queueGeometry()

    Loader {
        id: taskSource
        source: dockOptions.demo ? "DemoTasks.qml" : "LiveTasks.qml"
        onStatusChanged: if (status === Loader.Error) Qt.exit(1)
    }
    Rectangle {
        id: bar
        x: root.vertical ? (dockOptions.edge === 2 ? 8 : root.width - width - 8) : (root.width - width) / 2
        y: root.vertical ? (root.height - height) / 2 : (dockOptions.edge === 1 ? 8 : root.height - height - 8)
        width: root.vertical ? root.barThickness : root.barLength
        height: root.vertical ? root.barLength : root.barThickness
        radius: Geometry.radius(width, height, true, dockOptions.radius)
        color: Kirigami.Theme.backgroundColor
        border.color: Kirigami.Theme.disabledTextColor
        border.width: 1
        onXChanged: root.queueGeometry()
        onYChanged: root.queueGeometry()
        onWidthChanged: root.queueGeometry()
        onHeightChanged: root.queueGeometry()
        Loader {
            anchors.fill: parent
            active: dockOptions.glow
            sourceComponent: CapsuleGlow {
                cornerRadius: bar.radius
                pointerX: pointer.point.position.x - bar.x
                pointerY: pointer.point.position.y - bar.y
                hovering: pointer.hovered && Geometry.containsPoint(width, height, cornerRadius, pointerX, pointerY)
                glowColor: root.applicationColor
                glowRadius: root.maximum
            }
        }
    }
    // Rotate the layout axis only; icons counter-rotate to stay upright.
    Flickable {
        id: viewport
        width: root.length
        height: root.depth
        x: root.vertical ? (root.width - width) / 2 : 0
        y: root.vertical ? (root.height - height) / 2 : 0
        rotation: root.vertical ? 90 : 0
        clip: true
        contentWidth: Math.max(width, taskRow.width + 24)
        contentHeight: height
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentWidth > width
        onContentXChanged: root.queueGeometry()
        Row {
            id: taskRow
            x: Math.max(12, (viewport.width - width) / 2)
            height: viewport.height
            spacing: 10
            onXChanged: root.queueGeometry()
            onWidthChanged: root.queueGeometry()
            Repeater {
                id: repeater
                model: taskSource.item ? taskSource.item.tasks : null
                onCountChanged: root.queueGeometry()
                delegate: Item {
                    id: slot
                    objectName: "task" + index
                    required property int index
                    required property var model
                    readonly property real factor: root.hovering ? Math.max(0, 1 - Math.abs(root.pointerIndex - index) / 2.4) : 0
                    property real size: root.base + (root.maximum - root.base) * factor * factor
                    property alias iconItem: icon
                    width: size
                    height: viewport.height
                    Behavior on size { NumberAnimation { duration: 90 } }
                    onXChanged: root.queueGeometry()
                    onSizeChanged: root.queueGeometry()
                    Kirigami.Icon {
                        id: icon
                        objectName: "icon" + slot.index
                        width: slot.size; height: width
                        x: 0
                        // After a clockwise rotation, local bottom is the screen's left.
                        y: (dockOptions.edge === 1 || dockOptions.edge === 3) ? 18 : slot.height - height - 18
                        rotation: root.vertical ? -90 : 0
                        source: slot.model.decoration
                        roundToIconSize: false
                        onYChanged: root.queueGeometry()
                        TapHandler { onTapped: taskSource.item.activate(slot.index) }
                        HoverHandler {
                            id: iconHover
                            onHoveredChanged: if (hovered) root.applicationColor = colorLoader.item ? colorLoader.item.dominant : Kirigami.Theme.highlightColor
                        }
                        Controls.ToolTip.visible: iconHover.hovered
                        Controls.ToolTip.delay: 900
                        Controls.ToolTip.text: slot.model.display || ""
                    }
                    Loader {
                        id: colorLoader
                        active: dockOptions.glow
                        sourceComponent: Kirigami.ImageColors {
                            source: slot.model.decoration
                            onPaletteChanged: if (iconHover.hovered) root.applicationColor = dominant
                        }
                    }
                    Rectangle {
                        visible: !!slot.model.IsWindow
                        width: 4; height: 4; radius: 2
                        x: (slot.width - width) / 2
                        y: (dockOptions.edge === 1 || dockOptions.edge === 3) ? 12 : slot.height - 16
                        color: slot.model.IsActive ? Kirigami.Theme.highlightColor : Kirigami.Theme.textColor
                    }
                }
            }
        }
        WheelHandler {
            onWheel: event => {
                if (viewport.contentWidth > viewport.width) {
                    viewport.contentX = Math.max(0, Math.min(viewport.contentWidth - viewport.width,
                        viewport.contentX - event.angleDelta.y / 2));
                    event.accepted = true;
                }
            }
        }
    }
    Controls.Label {
        anchors.centerIn: bar
        visible: repeater.count === 0
        text: qsTr("Plasma Next Dock")
    }
    HoverHandler {
        id: pointer
        blocking: false
        onPointChanged: root.updatePointer(point.position)
        onHoveredChanged: dockController.setHovered(hovered)
    }
}
