// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts

ColumnLayout {
    id: measure
    required property string caption
    property alias value: field.value
    property alias from: field.from
    property alias to: field.to
    property alias stepSize: field.stepSize
    signal edited(int value)
    Controls.Label { text: measure.caption }
    Controls.SpinBox {
        id: field
        editable: true
        Accessible.name: measure.caption
        onValueModified: measure.edited(value)
    }
}
