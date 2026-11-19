// SPDX-FileCopyrightText: 2024 Matt Anis
// SPDX-License-Identifier: GPL-2.0-or-later
#include "backgroundeffects.h"
#include "geometry.h"
#include <KWindowEffects>
#include <QCoreApplication>
#include <QPlatformSurfaceEvent>

BackgroundEffects::BackgroundEffects(QQuickWindow *window, QObject *parent)
    : QObject(parent), m_window(window)
{
    if (window) window->installEventFilter(this);
    if (qApp) qApp->installEventFilter(this);
}
BackgroundEffects::~BackgroundEffects()
{
    if (qApp) qApp->removeEventFilter(this);
    if (m_window) m_window->removeEventFilter(this);
    clear();
}
void BackgroundEffects::configure(const QVariantMap &options)
{
    const int mode = options.value("backgroundType", 0).toInt();
    const bool enabled = mode == 3 || mode == 4;
    if (enabled == m_enabled) return;
    m_enabled = enabled;
    schedule();
}
void BackgroundEffects::setGeometry(const QPainterPath &capsule)
{
    if (capsule == m_capsule) return;
    m_capsule = capsule;
    schedule();
}
void BackgroundEffects::schedule(bool restore)
{
    m_restore |= restore;
    if (m_queued) return;
    m_queued = true;
    QMetaObject::invokeMethod(this, [this] { m_queued = false; apply(); }, Qt::QueuedConnection);
}
bool BackgroundEffects::eventFilter(QObject *object, QEvent *event)
{
    if (object == qApp && event->type() == QEvent::ApplicationPaletteChange) schedule(true);
    if (object == m_window) {
        switch (event->type()) {
        case QEvent::PlatformSurface:
            if (static_cast<QPlatformSurfaceEvent *>(event)->surfaceEventType() == QPlatformSurfaceEvent::SurfaceAboutToBeDestroyed) {
                clear(); // Forget requests while the old native surface still exists.
                m_surfaceDestroyed = true;
                m_restore = true;
            } else {
                m_surfaceDestroyed = false;
                schedule(true);
            }
            break;
        case QEvent::Resize:
            schedule();
            break;
        case QEvent::Show:
        case QEvent::Expose:
            schedule(true);
            break;
        default: break;
        }
    }
    return QObject::eventFilter(object, event);
}
void BackgroundEffects::clear()
{
    if (m_window && m_applied && !m_surfaceDestroyed) writeEffects(false, {});
    m_applied = false;
    m_lastRegion = {};
}
void BackgroundEffects::apply()
{
    if (!m_window || m_surfaceDestroyed) return;
    // An empty region means full-window blur to KWin, so never enable it.
    const QRegion region = QRegion(m_capsule.toFillPolygon().toPolygon())
        .intersected(QRect(QPoint(), m_window->size()));
    if (!m_enabled || region.isEmpty()) { clear(); return; }
    if (!m_window->isVisible() || !m_window->isExposed()) return;
    if (!m_restore && m_applied && region == m_lastRegion) return;
    // Lifecycle restoration must also bypass KWindowSystem's region cache.
    if (m_restore) clear();
    writeEffects(true, region);
    m_lastRegion = region;
    m_applied = true; m_restore = false;
    m_window->update(); // Commit changed Wayland state even while stationary.
}
void BackgroundEffects::writeEffects(bool enabled, const QRegion &region)
{
    KWindowEffects::enableBlurBehind(m_window, enabled, region);
}
