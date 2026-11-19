// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once
#include <QPainterPath>
#include <QRegion>
#include <QSize>
#include <QRectF>
namespace DockGeometry {
enum Edge { Bottom, Top, Left, Right };
enum Alignment { Start, Center, End };
enum Visibility { AlwaysVisible, AutoHide, DodgeWindows, WindowsGoBelow };
QRect surface(const QRect &screen, const QSize &size, Edge edge, Alignment alignment = Center);
QPainterPath capsule(const QRectF &rect, qreal radius);
QPainterPath capsule(const QRectF &rect, const QList<qreal> &corners, bool vertical);
QString svgPath(const QPainterPath &path);
QRegion inputRegion(const QRectF &capsuleRect, qreal radius, const QList<QRectF> &icons, const QRect &bounds, Edge edge = Bottom, const QPainterPath &shape = {});
bool overlaps(const QRectF &window, const QRectF &capsuleRect, qreal radius);
}
