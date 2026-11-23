// SPDX-License-Identifier: GPL-2.0-or-later
#include "geometry.h"
#include <algorithm>

namespace DockGeometry {

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
    // Cubic control distance for a quarter circle of unit radius.
    constexpr qreal controlDistance = 0.5522847498307936;
    for (int i = 0; i < 4; ++i) {
        const qreal r = std::clamp(corners[i], -limit, limit);
        const QPointF h((i == 0 || i == 3 ? 1 : -1) * (vertical ? std::abs(r) : r), 0);
        const QPointF v(0, (i < 2 ? 1 : -1) * (vertical ? r : std::abs(r)));
        const QPointF first = i % 2 ? h : v;
        const QPointF last = i % 2 ? v : h;
        const auto origin = origins[i];
        if (i == 0) path.moveTo(origin + first);
        else path.lineTo(origin + first);
        if (r) path.cubicTo(origin + first * (1 - controlDistance), origin + last * (1 - controlDistance), origin + last);
    }
    path.closeSubpath();
    return path;
}

// QML PathSvg consumes closed subpaths, including the hole in an exterior border.
static QString svgPath(const QPainterPath &path)
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

QVariantMap capsuleDrawing(QSizeF size, const QList<qreal> &corners, bool vertical, qreal border)
{
    const auto fill = capsule(QRectF(QPointF(), size), corners, vertical);
    QString outline;
    if (border > 0 && !fill.isEmpty()) {
        // Boolean path operations flatten curves. Work at higher precision
        // so the exterior ring stays smooth on scaled outputs.
        constexpr qreal pathScale = 8;
        const auto scale = QTransform::fromScale(pathScale, pathScale);
        const auto large = scale.map(fill);
        QPainterPathStroker stroke;
        // Half the centered stroke survives subtraction of the fill.
        stroke.setWidth(2 * pathScale * border);
        stroke.setJoinStyle(Qt::RoundJoin);
        outline = svgPath(scale.inverted().map(stroke.createStroke(large).subtracted(large)));
    }
    return {{"fill", svgPath(fill)}, {"outline", outline}};
}
}
