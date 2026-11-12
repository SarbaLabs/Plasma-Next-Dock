// SPDX-License-Identifier: GPL-2.0-or-later
#include "geometry.h"
#include <algorithm>
namespace DockGeometry {
QRect surface(const QRect &screen, const QSize &size, Edge edge)
{
    QRect rect(QPoint(), size.boundedTo(screen.size()));
    rect.moveTopLeft(screen.topLeft() + QPoint((screen.width() - rect.width()) / 2,
                                               (screen.height() - rect.height()) / 2));
    switch (edge) {
    case Bottom: rect.moveBottom(screen.bottom()); break;
    case Top: rect.moveTop(screen.top()); break;
    case Left: rect.moveLeft(screen.left()); break;
    case Right: rect.moveRight(screen.right()); break;
    }
    return rect;
}
QPainterPath capsule(const QRectF &rect, qreal radius)
{
    QPainterPath path;
    if (rect.isEmpty()) return path;
    radius = std::clamp(radius, 0.0, std::min(rect.width(), rect.height()) / 2);
    path.addRoundedRect(rect, radius, radius);
    return path;
}
QRegion inputRegion(const QRectF &rect, qreal radius, const QList<QRectF> &icons, const QRect &bounds)
{
    QRegion region(capsule(rect, radius).toFillPolygon().toPolygon());
    for (const auto &icon : icons) region += icon.toAlignedRect();
    return region.intersected(bounds);
}
bool overlaps(const QRectF &window, const QRectF &rect, qreal radius)
{
    return !window.isEmpty() && capsule(rect, radius).intersects(window);
}
}
