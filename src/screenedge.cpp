// SPDX-License-Identifier: GPL-2.0-or-later
// Uses KDE's MIT-CMU screen-edge protocol. See docs/licensing.md.
#include "screenedge.h"
#include "qwayland-kde-screen-edge-v1.h"
#include <QEvent>
#include <QPlatformSurfaceEvent>
#include <QWaylandClientExtension>
#include <qpa/qplatformwindow_p.h>

class EdgeManager : public QWaylandClientExtensionTemplate<EdgeManager>, public QtWayland::kde_screen_edge_manager_v1
{
public:
    EdgeManager() : QWaylandClientExtensionTemplate(1) { initialize(); }
    ~EdgeManager() override { if (isInitialized()) destroy(); }
};
class EdgeObject : public QtWayland::kde_auto_hide_screen_edge_v1
{
public:
    explicit EdgeObject(::kde_auto_hide_screen_edge_v1 *edge) : QtWayland::kde_auto_hide_screen_edge_v1(edge) {}
    ~EdgeObject() override { destroy(); }
};
class ScreenEdge::Private
{
public:
    QWindow *window;
    DockGeometry::Edge edge;
    EdgeManager manager;
    std::unique_ptr<EdgeObject> object;
    bool requested = false;
    bool armed = false;
};
ScreenEdge::ScreenEdge(QWindow *window, DockGeometry::Edge edge) : QObject(window), d(std::make_unique<Private>())
{
    d->window = window;
    d->edge = edge;
    window->installEventFilter(this);
    connect(&d->manager, &QWaylandClientExtension::activeChanged, this, [this] {
        if (!available()) { d->object.reset(); d->armed = false; }
        synchronize();
        Q_EMIT availabilityChanged(available());
    });
}
ScreenEdge::~ScreenEdge() = default;
bool ScreenEdge::available() const { return d->manager.isActive(); }
void ScreenEdge::setHidden(bool hidden)
{
    d->requested = hidden;
    synchronize();
}
bool ScreenEdge::eventFilter(QObject *object, QEvent *event)
{
    if (event->type() == QEvent::Expose) synchronize();
    if (event->type() == QEvent::Hide
        || (event->type() == QEvent::PlatformSurface
            && static_cast<QPlatformSurfaceEvent *>(event)->surfaceEventType() == QPlatformSurfaceEvent::SurfaceAboutToBeDestroyed)) {
        d->object.reset();
        d->armed = false;
    }
    return QObject::eventFilter(object, event);
}
void ScreenEdge::synchronize()
{
    if (!available()) return;
    if (!d->object) {
        if (!d->window->isExposed()) return;
        auto *native = d->window->nativeInterface<QNativeInterface::Private::QWaylandWindow>();
        if (!native || !native->surface()) return;
        uint32_t border = QtWayland::kde_screen_edge_manager_v1::border_bottom;
        switch (d->edge) {
        case DockGeometry::Top: border = QtWayland::kde_screen_edge_manager_v1::border_top; break;
        case DockGeometry::Left: border = QtWayland::kde_screen_edge_manager_v1::border_left; break;
        case DockGeometry::Right: border = QtWayland::kde_screen_edge_manager_v1::border_right; break;
        case DockGeometry::Bottom: break;
        }
        d->object = std::make_unique<EdgeObject>(d->manager.get_auto_hide_screen_edge(border, native->surface()));
        d->armed = false;
    }
    if (d->armed == d->requested) return;
    d->armed = d->requested;
    if (d->armed) d->object->activate();
    else d->object->deactivate();
    // Do not hide/unmap QWindow: KWin owns edge recall. Pointer entry after
    // recall clears requested; leaving can arm it again if overlap remains.
}
