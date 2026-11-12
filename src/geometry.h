// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once
#include <QPainterPath>
#include <QRegion>
#include <QSize>
#include <QRectF>
namespace DockGeometry {
enum Edge { Bottom, Top, Left, Right };
QRect surface(const QRect &screen, const QSize &size, Edge edge);
QPainterPath capsule(const QRectF &rect, qreal radius);
QRegion inputRegion(const QRectF &capsuleRect, qreal radius, const QList<QRectF> &icons, const QRect &bounds);
bool overlaps(const QRectF &window, const QRectF &capsuleRect, qreal radius);
}
