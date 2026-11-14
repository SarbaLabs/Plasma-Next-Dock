/*
    SPDX-FileCopyrightText: 2020 Aleix Pol Gonzalez <aleixpol@kde.org>
    SPDX-License-Identifier: LGPL-2.0-or-later
*/
// Adapted from Plasma macOS Dock's PipeWireThumbnail.qml. The capture request
// exists only while its visible preview delegate is loaded.
import QtQuick
import org.kde.pipewire as PipeWire
import org.kde.taskmanager as TaskManager
PipeWire.PipeWireSourceItem {
    property string windowId: ""
    readonly property alias hasThumbnail: thumbnail.ready
    id: thumbnail
    nodeId: request.nodeId
    TaskManager.ScreencastingRequest { id: request; uuid: thumbnail.windowId }
}
