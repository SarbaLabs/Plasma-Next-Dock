// SPDX-License-Identifier: GPL-2.0-or-later
#include "geometry.h"
#include <algorithm>
namespace DockGeometry {
QMargins alignmentMargins(const QSize &screen, const QSize &size, Edge edge, Alignment alignment, int margin)
{
    const bool vertical = edge == Left || edge == Right;
    const int space = vertical ? screen.height() - size.height() : screen.width() - size.width();
    const int offset = std::clamp(margin, 0, std::max(0, space));
    QMargins margins;
    if (alignment == Start) {
        if (vertical) margins.setTop(offset);
        else margins.setLeft(offset);
    } else if (alignment == End) {
        if (vertical) margins.setBottom(offset);
        else margins.setRight(offset);
    }
    return margins;
}

QRect surface(const QRect &screen, const QSize &size, Edge edge, Alignment alignment)
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
    if (edge == Left || edge == Right) {
        if (alignment == Start) rect.moveTop(screen.top());
        if (alignment == End) rect.moveBottom(screen.bottom());
    } else {
        if (alignment == Start) rect.moveLeft(screen.left());
        if (alignment == End) rect.moveRight(screen.right());
    }
    return rect;
}

QRegion inputRegion(const QRectF &rect, const QPainterPath &shape, const QList<QRectF> &icons, const QRect &bounds, Edge edge)
{
    QRegion region(shape.toFillPolygon().toPolygon());
    if (!rect.isEmpty()) {
        // The entire recall span must receive pointer entry, including empty ends.
        // Keep at least one edge pixel even at zero spacing. A connector fills
        // the outward rounded corners without expanding dodge.
        QRectF strip(bounds);
        QRectF connector(rect);
        switch (edge) {
        case Bottom:
            strip.setTop(std::min(rect.bottom(), qreal(bounds.y() + bounds.height() - 1)));
            connector.setTop(rect.center().y());
            connector.setBottom(bounds.y() + bounds.height());
            break;
        case Top:
            strip.setBottom(std::max(rect.top(), qreal(bounds.top() + 1)));
            connector.setBottom(rect.center().y());
            connector.setTop(bounds.top());
            break;
        case Left:
            strip.setRight(std::max(rect.left(), qreal(bounds.left() + 1)));
            connector.setRight(rect.center().x());
            connector.setLeft(bounds.left());
            break;
        case Right:
            strip.setLeft(std::min(rect.right(), qreal(bounds.x() + bounds.width() - 1)));
            connector.setLeft(rect.center().x());
            connector.setRight(bounds.x() + bounds.width());
            break;
        }
        region += strip.toAlignedRect();
        region += connector.toAlignedRect();
    }
    for (const auto &icon : icons) region += icon.toAlignedRect();
    return region.intersected(bounds);
}
}
