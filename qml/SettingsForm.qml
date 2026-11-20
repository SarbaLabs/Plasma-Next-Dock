// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.FormLayout {
    // Long localized help text should not switch an entire desktop page to one column.
    wideMode: width >= 680
    implicitWidth: Math.min(width, 760)
    Layout.minimumWidth: 0
}
