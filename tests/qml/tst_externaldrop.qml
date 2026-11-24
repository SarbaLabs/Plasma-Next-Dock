// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtTest
import "qrc:/qml" as Dock

TestCase {
    id: test
    name: "ExternalDrop"
    width: 400; height: 400; visible: true
    when: windowShown
    QtObject {
        id: fakeTasks
        property int opens: 0
        property int activations: 0
        property var received: []
        function requestOpenUrls(index, urls) { opens++; received = urls; }
        function requestActivate(index) { activations++; }
        function makeModelIndex(row, child) { return {row: row, child: child}; }
    }
    QtObject {
        id: fakeSource
        property var tasks: fakeTasks
        property var pins: []
        property string before: ""
        function insertLaunchers(urls, anchor) { pins = urls; before = anchor; return true; }
    }
    QtObject {
        id: fakeTarget
        property bool valid: false
        property var index: ({row: -1})
        function bind(model, row) { valid = model !== null && row >= 0; index = {row: row}; }
        property bool group: false
        function data(role) { return role === "IsWindow" || (group && role === "IsGroupParent"); }
    }
    Component {
        id: dropComponent
        Dock.ExternalDrop {
            width: 300; height: 300
            tasksSource: fakeSource
            resolver: launcherResolver
            target: fakeTarget
            hitTest: point => point.x < 200 ? 0 : -1
            insertionAnchor: point => "applications:Second.desktop"
        }
    }
    function init() { failOnWarning(/.*(TypeError|ReferenceError).*/); fakeTarget.group = false; fakeTasks.opens = 0; fakeTasks.activations = 0; fakeSource.pins = []; fakeTarget.bind(null, -1); }
    Component { id: viewportFixture; Flickable { width: 300; height: 300; contentWidth: 1000 } }
    function test_overflowScroll_data() {
        return [{tag: "document", urls: ["file:///tmp/document.txt"]},
                {tag: "launcher", urls: [testLauncherUrls[0]]}];
    }
    function test_overflowScroll(data) {
        const view = createTemporaryObject(viewportFixture, test);
        const drop = createTemporaryObject(dropComponent, test, {scrollView: view});
        drop.hitTest = point => Math.floor((point.x + view.contentX) / 40);
        drop.insertionAnchor = point => String(drop.hitTest(point));
        const end = Qt.point(295, 150), start = Qt.point(5, 150), middle = Qt.point(150, 150);
        verify(drop.begin(data.urls, end));
        tryVerify(() => view.contentX >= 210);
        compare(fakeTasks.activations, 0);
        if (drop.kind === "documents") compare(fakeTarget.index.row, drop.hitTest(end));
        drop.locate(middle);
        const paused = view.contentX;
        wait(120);
        compare(view.contentX, paused);
        drop.locate(start);
        tryVerify(() => view.contentX < paused);
        drop.clear();
        const cancelled = view.contentX;
        wait(120);
        compare(view.contentX, cancelled);
        view.contentX = 694;
        verify(drop.begin(data.urls, end));
        tryCompare(view, "contentX", 700);
        compare(drop.scrollDirection, 0);
        if (drop.kind === "documents") compare(fakeTarget.index.row, drop.hitTest(end));
        verify(drop.commit(data.urls, end));
        if (data.tag === "launcher") compare(fakeSource.before, String(drop.hitTest(end)));
        view.contentWidth = view.width;
        verify(drop.begin(data.urls, end));
        compare(drop.scrollDirection, 0);
        drop.clear();
    }
    function test_nativeDragEventDelivery() {
        const drop = createTemporaryObject(dropComponent, test);
        const urls = ["file:///tmp/document.txt"];
        verify(testEnvironment.externalDrag(drop, Qt.point(40, 40), urls, 0));
        compare(drop.containsDrag, true);
        compare(drop.kind, "documents");
        verify(testEnvironment.externalDrag(drop, Qt.point(60, 60), urls, 1));
        verify(testEnvironment.externalDrag(drop, Qt.point(60, 60), urls, 2));
        compare(fakeTasks.opens, 1);
        compare(drop.containsDrag, false);
        verify(!fakeTarget.valid);
        verify(testEnvironment.externalDrag(drop, Qt.point(40, 40), urls, 0));
        testEnvironment.externalDrag(drop, Qt.point(40, 40), urls, 3);
        compare(drop.containsDrag, false);
        compare(drop.kind, "");
    }
    function test_insertionAllEdges() {
        const saved = JSON.parse(JSON.stringify(dockSettings.values));
        const component = Qt.createComponent("qrc:/qml/Main.qml");
        compare(component.status, Component.Ready, component.errorString());
        const dock = createTemporaryObject(component, test);
        try {
            dockSettings.saveLaunchers(["applications:First.desktop", "applications:Second.desktop"]);
            const source = findChild(dock, "taskSourceLoader");
            source.source = Qt.resolvedUrl("LaunchingTasks.qml");
            tryCompare(source, "status", Loader.Ready);
            source.item.tasks.setProperty(0, "LauncherUrl", "applications:First.desktop");
            source.item.tasks.setProperty(1, "LauncherUrl", "applications:Second.desktop");
            const area = findChild(dock, "externalDrop");
            for (let edge = 0; edge < 4; ++edge) {
                testEnvironment.setEdge(edge);
                wait(30);
                const icon = findChild(dock, "icon0");
                const center = icon.mapToItem(dock, icon.width / 2, icon.height / 2);
                const before = Qt.point(center.x - (edge < 2 ? 2 : 0), center.y - (edge >= 2 ? 2 : 0));
                const after = Qt.point(center.x + (edge < 2 ? 2 : 0), center.y + (edge >= 2 ? 2 : 0));
                compare(area.insertionAnchor(before), "applications:First.desktop");
                compare(area.insertionAnchor(after), "applications:Second.desktop");
            }
        } finally { dockSettings.apply(saved); }
    }
    function test_catalogAndCanonicalIdentity() {
        const apps = launcherResolver.applications();
        verify(apps.some(app => app.url === "applications:First.desktop"));
        compare(launcherResolver.launcher(testLauncherUrls[0]), "applications:First.desktop");
        compare(launcherResolver.launcher("applications:Missing.desktop"), "");
        compare(launcherResolver.launcher("file:///tmp/untrusted.desktop"), "");
        compare(launcherResolver.insert([testLauncherUrls[0]], ["applications:First.desktop"], "").length, 1);
        compare(launcherResolver.insert([testLauncherUrls[1]], [testLauncherUrls[0]], testLauncherUrls[1])[0], "applications:First.desktop");
        compare(launcherResolver.classify([testLauncherUrls[0], "file:///tmp/file.txt"]).kind, undefined);
        compare(launcherResolver.classify(["javascript:alert(1)"]).kind, undefined);
    }
    function test_documentTargetAndDwellCancellation() {
        const drop = createTemporaryObject(dropComponent, test);
        verify(drop.begin(["file:///tmp/document.txt"], Qt.point(40, 40)));
        wait(700);
        compare(fakeTasks.activations, 1);
        verify(drop.commit(["file:///tmp/document.txt"], Qt.point(40, 40)));
        compare(fakeTasks.opens, 1);
        verify(!fakeTarget.valid);
        verify(drop.begin(["file:///tmp/document.txt"], Qt.point(40, 40)));
        fakeTarget.valid = false; // Window disappeared before deferred activation/drop.
        wait(700);
        compare(fakeTasks.activations, 1);
        verify(!drop.commit(["file:///tmp/document.txt"], Qt.point(40, 40)));
        compare(fakeTasks.opens, 1);
        verify(drop.begin(["file:///tmp/document.txt"], Qt.point(40, 40)));
        drop.clear(); wait(700);
        compare(fakeTasks.activations, 1);
    }
    function test_groupDwellOnlyOpensChooser() {
        const drop = createTemporaryObject(dropComponent, test);
        let group = -1;
        drop.groupHovered.connect(row => group = row);
        fakeTarget.group = true;
        verify(drop.begin(["file:///tmp/document.txt"], Qt.point(40, 40)));
        tryVerify(() => group === 0);
        compare(fakeTasks.activations, 0);
        verify(drop.commit(["file:///tmp/document.txt"], Qt.point(40, 40)));
        compare(fakeTasks.opens, 1);
    }
    function test_pinAndRejectMixedPayload() {
        const drop = createTemporaryObject(dropComponent, test);
        verify(drop.begin([testLauncherUrls[0]], Qt.point(40, 40)));
        verify(drop.commit([testLauncherUrls[0]], Qt.point(40, 40)));
        compare(fakeSource.pins[0], "applications:First.desktop");
        compare(fakeSource.before, "applications:Second.desktop");
        compare(fakeTasks.opens, 0);
        verify(!drop.begin(["file:///tmp/unknown.desktop"], Qt.point(40, 40)));
        verify(drop.begin(["file:///tmp/document.txt"], Qt.point(40, 40)));
        verify(!drop.commit([testLauncherUrls[0]], Qt.point(40, 40)));
    }
    function test_chooserSearch() {
        const c = Qt.createComponent("qrc:/qml/ApplicationChooser.qml");
        compare(c.status, Component.Ready, c.errorString());
        const chooser = createTemporaryObject(c, test);
        verify(chooser !== null);
        chooser.applications = launcherResolver.applications();
        const search = findChild(chooser, "applicationSearch");
        verify(search !== null);
        search.text = "First";
        verify(chooser.matches.length > 0);
        verify(chooser.matches.every(app => (app.name + app.description + app.url).toLowerCase().includes("first")));
        search.text = "no-such-app-78543";
        compare(chooser.matches.length, 0);
    }
}
