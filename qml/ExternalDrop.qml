// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import "code/AdaptiveLayout.js" as Adaptive

// Native external DnD only. Internal reordering keeps its existing DragHandler.
DropArea {
    id: root
    objectName: "externalDrop"
    required property var tasksSource
    required property var hitTest
    required property var insertionAnchor
    required property var resolver
    required property var target
    property bool hasLocalMoveTarget: false
    property var moduleEntryAt: null
    property bool localFiles: false
    property var moduleDrop: null
    property var directoryReceiver: null
    property Flickable scrollView: null
    // The viewport's local x axis runs along all four screen edges.
    readonly property int scrollDirection: {
        if (!enabled || !located || !kind || !scrollView || scrollView.contentWidth <= scrollView.width) return 0;
        const p = scrollView.mapFromItem(root, dragPoint);
        if (!scrollView.contains(p)) return 0;
        const zone = Math.min(28, scrollView.width / 4);
        if (p.x < zone && scrollView.contentX > 0) return -1;
        if (p.x > scrollView.width - zone && scrollView.contentX < scrollView.contentWidth - scrollView.width) return 1;
        return 0;
    }
    property string kind: ""
    property var launchers: []
    property bool located: false
    property point dragPoint: Qt.point(0, 0)
    signal groupHovered(int row)
    signal targetChangedDuringDrag(int row)
    signal openedFiles(int row)
    function clear() {
        located = false; localFiles = false; kind = ""; launchers = []; dwell.stop();
        target.bind(null, -1);
    }
    function locate(point, afterScroll = false) {
        if (!afterScroll && located && point.x === dragPoint.x && point.y === dragPoint.y) return;
        dragPoint = point;
        located = true;
        if (kind !== "documents" || !tasksSource) return;
        const row = hitTest(point);
        if (target.valid && target.index.row === row) return;
        targetChangedDuringDrag(row);
        target.bind(tasksSource.tasks, row);
        updateDwell();
    }
    function updateDwell() {
        dwell.stop();
        if (located && !scrollDirection && kind === "documents" && target.valid
            && (target.data("IsWindow") || target.data("IsGroupParent"))) dwell.start();
    }
    function dropKind(plan) {
        if (plan.directoriesOnly && directoryReceiver?.acceptsDirectories()) return "directories";
        return plan.kind || (plan.localFiles && hasLocalMoveTarget ? "localFiles" : "");
    }
    function begin(urls, point) {
        clear();
        const plan = resolver.classify(urls);
        kind = dropKind(plan);
        if (!kind) return false;
        localFiles = !!plan.localFiles;
        launchers = plan.launchers || [];
        locate(point);
        return true;
    }
    function actionAt(point, supported) {
        const entry = moduleEntryAt?.(point);
        if (entry?.localFileMove) {
            if (!entry.acceptsDocuments || entry.enabled === false) return Qt.IgnoreAction;
            return localFiles && (supported & Qt.MoveAction) ? Qt.MoveAction : Qt.IgnoreAction;
        }
        return kind !== "localFiles" && (supported & Qt.CopyAction) ? Qt.CopyAction : Qt.IgnoreAction;
    }
    function commit(urls, point, supported = Qt.CopyAction | Qt.MoveAction) {
        if (!tasksSource) { clear(); return false; }
        if (point.x !== dragPoint.x || point.y !== dragPoint.y) locate(point);
        // Validate the actual payload again at drop time, not just the offer.
        const plan = resolver.classify(urls);
        if (!kind || dropKind(plan) !== kind) { clear(); return false; }
        let accepted = false;
        const action = actionAt(point, supported);
        if (action === Qt.IgnoreAction) { clear(); return false; }
        if (action === Qt.MoveAction) {
            accepted = plan.localFiles && moduleDrop && moduleDrop(point, urls);
        } else if (kind === "applications") {
            accepted = tasksSource.insertLaunchers(plan.launchers, insertionAnchor(point));
        } else if (kind === "directories") {
            // An explicit folder target gets the copy, even on an otherwise empty dock.
            const handled = moduleDrop ? moduleDrop(point, urls) : undefined;
            accepted = handled ?? directoryReceiver.dropDirectories(urls);
        } else if (moduleDrop && moduleDrop(point, urls)) {
            accepted = true;
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
    onEntered: event => {
        const point = Qt.point(event.x, event.y);
        event.accepted = event.hasUrls && begin(event.urls, point)
            && ((event.supportedActions & Qt.CopyAction) || (localFiles && hasLocalMoveTarget && (event.supportedActions & Qt.MoveAction)));
        // Keep tracking across the single dock surface, even when the first slot is busy.
        if (event.accepted) event.action = actionAt(point, event.supportedActions);
    }
    onPositionChanged: event => {
        const point = Qt.point(event.x, event.y);
        locate(point);
        // Qt Wayland also needs the move event rejected to display the forbidden cursor.
        const action = actionAt(point, event.supportedActions);
        event.action = action;
        event.accepted = action !== Qt.IgnoreAction;
    }
    onExited: clear()
    onScrollDirectionChanged: updateDwell()
    Timer {
        interval: 50
        repeat: true
        running: root.scrollDirection !== 0
        onTriggered: {
            const view = root.scrollView;
            view.contentX = Adaptive.scrollPosition(view.contentX, root.scrollDirection * 14, view.contentWidth, view.width);
            // A stationary pointer now covers a different task.
            root.locate(root.dragPoint, true);
        }
    }
    onDropped: event => {
        const point = Qt.point(event.x, event.y);
        const action = actionAt(point, event.supportedActions);
        if (commit(event.urls, point, event.supportedActions)) event.accept(action);
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
