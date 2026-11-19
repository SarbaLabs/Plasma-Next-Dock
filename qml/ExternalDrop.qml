// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick

// Native external DnD only. Internal reordering keeps its existing DragHandler.
DropArea {
    id: root
    objectName: "externalDrop"
    required property var tasksSource
    required property var hitTest
    required property var insertionAnchor
    required property var resolver
    required property var target
    property string kind: ""
    property var launchers: []
    property bool located: false
    property point dragPoint: Qt.point(0, 0)
    signal groupHovered(int row)
    signal targetChangedDuringDrag(int row)
    signal openedFiles(int row)
    function clear() {
        dwell.stop(); kind = ""; launchers = []; located = false;
        target.bind(null, -1);
    }
    function locate(point) {
        if (located && point.x === dragPoint.x && point.y === dragPoint.y) return;
        located = true;
        dragPoint = point;
        if (kind !== "documents" || !tasksSource) return;
        const row = hitTest(point);
        if (target.valid && target.index.row === row) return;
        targetChangedDuringDrag(row);
        target.bind(tasksSource.tasks, row);
        dwell.stop();
        if (target.valid && (target.data("IsWindow") || target.data("IsGroupParent"))) dwell.start();
    }
    function begin(urls, point) {
        clear();
        const plan = resolver.classify(urls);
        if (!plan.kind) return false;
        kind = plan.kind; launchers = plan.launchers;
        locate(point);
        return true;
    }
    function commit(urls, point) {
        if (!tasksSource) { clear(); return false; }
        if (point.x !== dragPoint.x || point.y !== dragPoint.y) locate(point);
        // Validate the actual payload again at drop time, not just the offer.
        const plan = resolver.classify(urls);
        if (!plan.kind || plan.kind !== kind) { clear(); return false; }
        let accepted = false;
        if (kind === "applications") {
            accepted = tasksSource.insertLaunchers(plan.launchers, insertionAnchor(point));
        } else if (target.valid) {
            const row = target.index.row;
            const index = target.index;
            openedFiles(row);
            tasksSource.tasks.requestOpenUrls(index, urls);
            accepted = true;
        }
        clear();
        return accepted;
    }
    onEntered: event => { event.accepted = event.hasUrls && (event.supportedActions & Qt.CopyAction) && begin(event.urls, Qt.point(event.x, event.y)); }
    onPositionChanged: event => locate(Qt.point(event.x, event.y))
    onExited: clear()
    onDropped: event => {
        if ((event.supportedActions & Qt.CopyAction) && commit(event.urls, Qt.point(event.x, event.y))) event.accept(Qt.CopyAction);
        else { clear(); event.accepted = false; }
    }
    Timer {
        id: dwell
        interval: 650; repeat: false
        onTriggered: {
            if (!root.tasksSource || !root.target.valid) return;
            const index = root.target.index;
            if (root.target.data("IsGroupParent")) {
                root.groupHovered(index.row);
                return;
            }
            if (!root.target.data("IsWindow")) return;
            // Activation only: never toggle minimization during a drag.
            root.tasksSource.tasks.requestActivate(index);
        }
    }
    Component.onDestruction: clear()
}
