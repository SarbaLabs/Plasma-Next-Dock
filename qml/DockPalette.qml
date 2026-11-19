// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import org.kde.kirigami as Kirigami

Item {
    id: root
    visible: false
    SystemPalette { id: system; colorGroup: SystemPalette.Active }
    readonly property var keys: ["custom", "automatic", "window", "windowText", "base", "alternateBase",
        "text", "highlight", "highlightedText", "button", "buttonText", "link", "disabled", "positive", "neutral", "negative"]
    readonly property var labels: [i18n("Fixed color"), i18n("Theme default"), i18n("Window background"), i18n("Window text"),
        i18n("View background"), i18n("Alternate view background"), i18n("View text"), i18n("Highlight"),
        i18n("Highlighted text"), i18n("Button background"), i18n("Button text"), i18n("Link"),
        i18n("Disabled text"), i18n("Positive text"), i18n("Neutral text"), i18n("Negative text")]
    function resolve(key, fixed, fallback) {
        switch (key) {
        case "custom": return fixed;
        case "link": return Kirigami.Theme.linkColor;
        case "disabled": return Kirigami.Theme.disabledTextColor;
        case "positive": return Kirigami.Theme.positiveTextColor;
        case "neutral": return Kirigami.Theme.neutralTextColor;
        case "negative": return Kirigami.Theme.negativeTextColor;
        case "automatic": return fallback;
        default: return keys.includes(key) ? system[key] : fallback;
        }
    }
}
