// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once
#include <QDrag>
#include <QGuiApplication>
#include <QIcon>
#include <QMimeData>
#include <QQuickWindow>

// Native launcher offers are copy-only. An optional marker identifies the origin.
inline void startLauncherDrag(QQuickWindow *window, const QUrl &url, const QString &iconName, const QString &format)
{
    const auto image = QIcon::fromTheme(iconName, QIcon::fromTheme(QStringLiteral("application-x-executable")))
                           .pixmap(QSize(32, 32), window->devicePixelRatio());

    // QDrag runs a nested event loop. A successful drop can close the
    // popup and destroy the delegate that requested it. Unwind the QML
    // handler first and give the drag a source that outlives both windows.
    QMetaObject::invokeMethod(window, [window, url, format, image] {
        if (!window->isVisible()) return;
        auto *drag = new QDrag(qGuiApp);
        auto *mime = new QMimeData;
        mime->setUrls({url});
        if (!format.isEmpty()) mime->setData(format, url.path().toUtf8());
        drag->setMimeData(mime);
        drag->setPixmap(image);
        drag->setHotSpot(QPoint(16, 16));
        drag->exec(Qt::CopyAction);
    }, Qt::QueuedConnection);
}
