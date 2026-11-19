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
QPainterPath capsule(const QRectF &rect, qreal radius)
{
    QPainterPath path;
    if (rect.isEmpty()) return path;
    radius = std::clamp(radius, 0.0, std::min(rect.width(), rect.height()) / 2);
    path.addRoundedRect(rect, radius, radius);
    return path;
}
// Physical corners are clockwise from top left. A negative corner extends
// along the long axis, with its outer tip tangent to the screen edge.
QPainterPath capsule(const QRectF &rect, const QList<qreal> &corners, bool vertical)
{
    QPainterPath path;
    if (rect.isEmpty() || corners.size() != 4) return path;
    const qreal limit = std::min(rect.width(), rect.height()) / 2;
    const QPointF origins[] = {rect.topLeft(), rect.topRight(), rect.bottomRight(), rect.bottomLeft()};
    constexpr qreal k = 0.5522847498307936;
    for (int i = 0; i < 4; ++i) {
        const qreal r = std::clamp(corners[i], -limit, limit);
        const QPointF h((i == 0 || i == 3 ? 1 : -1) * (vertical ? std::abs(r) : r), 0);
        const QPointF v(0, (i < 2 ? 1 : -1) * (vertical ? r : std::abs(r)));
        const QPointF first = i % 2 ? h : v, last = i % 2 ? v : h;
        const auto origin = origins[i];
        if (i == 0) path.moveTo(origin + first);
        else path.lineTo(origin + first);
        if (r) path.cubicTo(origin + first * (1-k), origin + last * (1-k), origin + last);
    }
    path.closeSubpath();
    return path;
}

QString svgPath(const QPainterPath &path)
{
    QString svg;
    auto point = [](const QPainterPath::Element &e) {
        return QString::number(e.x, 'f', 3) + ' ' + QString::number(e.y, 'f', 3) + ' ';
    };
    for (int i = 0; i < path.elementCount(); ++i) {
        auto e = path.elementAt(i);
        if (e.isMoveTo()) {
            if (i) svg += 'Z';
            svg += 'M' + point(e);
        } else if (e.isLineTo()) svg += 'L' + point(e);
        else if (e.isCurveTo()) {
            svg += 'C' + point(e);
            svg += point(path.elementAt(++i));
            svg += point(path.elementAt(++i));
        }
    }
    if (!svg.isEmpty()) svg += 'Z';
    return svg;
}

QRegion inputRegion(const QRectF &rect, qreal radius, const QList<QRectF> &icons, const QRect &bounds, Edge edge, const QPainterPath &shape)
{
    QRegion region((shape.isEmpty() ? capsule(rect, radius) : shape).toFillPolygon().toPolygon());
    if (!rect.isEmpty()) {
        // The entire recall span must receive pointer entry, including empty ends.
        // Keep at least one edge pixel even at zero spacing. A connector fills
        // the outward rounded corners without expanding dodge.
        QRectF strip(bounds), connector(rect);
        switch (edge) {
        case Bottom:
            strip.setTop(std::min(rect.bottom(), qreal(bounds.y() + bounds.height() - 1))); connector.setTop(rect.center().y());
            connector.setBottom(bounds.y() + bounds.height()); break;
        case Top:
            strip.setBottom(std::max(rect.top(), qreal(bounds.top() + 1))); connector.setBottom(rect.center().y());
            connector.setTop(bounds.top()); break;
        case Left:
            strip.setRight(std::max(rect.left(), qreal(bounds.left() + 1))); connector.setRight(rect.center().x());
            connector.setLeft(bounds.left()); break;
        case Right:
            strip.setLeft(std::min(rect.right(), qreal(bounds.x() + bounds.width() - 1))); connector.setLeft(rect.center().x());
            connector.setRight(bounds.x() + bounds.width()); break;
        }
        region += strip.toAlignedRect();
        region += connector.toAlignedRect();
    }
    for (const auto &icon : icons) region += icon.toAlignedRect();
    return region.intersected(bounds);
}
bool overlaps(const QRectF &window, const QRectF &rect, qreal radius)
{
    return !window.isEmpty() && capsule(rect, radius).intersects(window);
}
}
