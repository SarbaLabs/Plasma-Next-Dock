// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import org.kde.ksvg as KSvg
import org.kde.kirigami as Kirigami
import org.kde.taskmanager as TaskManager
import "code/IndicatorLogic.js" as Logic

// Coordinates use the upright resting lane, not the magnified icon.
Item {
    id: root
    required property var configuration
    required property var task
    required property var tasksModel
    required property int taskIndex
    property int edge: 0
    property real padding: 10
    property bool hovered: false
    // Background follows the inward icon envelope; the outward edge stays fixed.
    property real decorationExtent: edge < 2 ? height : width
    readonly property real decorationExtra: Math.max(0, decorationExtent - (edge < 2 ? height : width))
    Kirigami.Theme.inherit: false
    Kirigami.Theme.colorGroup: Kirigami.Theme.Active
    property color dominantColor: "transparent"
    readonly property int mode: Logic.mode(configuration)
    readonly property bool running: !!task.IsWindow || !!task.IsGroupParent
    readonly property int windowCount: Logic.count(running, !!task.IsGroupParent, task.ChildCount)
    readonly property bool decorations: Logic.nativeEnabled(configuration.taskDecorations, mode, false)
    readonly property bool groupSymbol: Logic.nativeEnabled(configuration.nativeGroupIndicator, mode, false) && windowCount > 1
    readonly property string state: task.IsDemandingAttention ? "attention" : task.IsActive ? "focus" : task.IsMinimized ? "minimized" : running ? "normal" : "launcher"
    function prefixesFor(state) { return [["south-", "north-", "west-", "east-"][edge] + state, state]; }
    readonly property var prefixes: hovered ? prefixesFor(state + "-hover").concat(prefixesFor("hover"), prefixesFor(state)) : prefixesFor(state)
    readonly property real framePadX: edge < 2 ? padding / 2 : padding
    readonly property real framePadY: edge < 2 ? padding : padding / 2
    Loader {
        objectName: "taskDecoration"
        x: -root.framePadX - (root.edge === 3 ? root.decorationExtra : 0)
        y: -root.framePadY - (root.edge === 0 ? root.decorationExtra : 0)
        width: root.width + 2 * root.framePadX + (root.edge >= 2 ? root.decorationExtra : 0)
        height: root.height + 2 * root.framePadY + (root.edge < 2 ? root.decorationExtra : 0)
        active: root.decorations
        sourceComponent: KSvg.FrameSvgItem { imagePath: "widgets/tasks"; prefix: root.prefixes }
    }
    Loader {
        x: -root.framePadX; y: -root.framePadY
        width: root.width + 2 * root.framePadX; height: root.height + 2 * root.framePadY
        active: root.mode === 1 && root.running && !root.decorations
        sourceComponent: NativeTaskIndicator { edge: root.edge; prefixes: root.prefixes }
    }
    Loader {
        anchors.fill: parent
        active: root.mode === 2 && root.running && Logic.flag(root.configuration, "customIndicatorsEnabled", true)
        sourceComponent: CustomIndicators {
            objectName: "customTaskIndicators"
            configuration: root.configuration
            effectiveEdge: root.edge
            horizontalPadding: root.padding; verticalPadding: root.padding
            windowCount: root.windowCount
            activeIndex: state.activeIndex
            minimizedWindows: state.minimizedWindows
            hovered: root.hovered
            dominantColor: root.dominantColor
            readonly property IndicatorTaskState state: IndicatorTaskState {
                tasksModel: root.tasksModel
                taskIndex: root.taskIndex
                minimizedRole: TaskManager.AbstractTasksModel.IsMinimized
                enabled: true
                grouped: !!root.task.IsGroupParent
                active: !!root.task.IsActive
                minimized: !!root.task.IsMinimized
                windowCount: root.windowCount
                limit: Logic.number(root.configuration, "indicatorMaxSegments", 4, 1, 8)
            }
        }
    }
    Loader {
        anchors.fill: parent
        active: root.groupSymbol
        sourceComponent: Item {
            GroupExpanderOverlay {
                iconTarget: root
                edge: root.edge
                grouped: true
                // Keep the native symbol at the lane end, away from centered dots.
                x: root.edge < 2 ? (root.mode === 1 ? (root.width - width) / 2 : root.width - width) : root.edge === 2 ? -width : root.width
                y: root.edge >= 2 ? (root.mode === 1 ? (root.height - height) / 2 : root.height - height) : root.edge === 1 ? -height : root.height
            }
        }
    }
}
