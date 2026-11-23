// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once
#include <QPainterPath>
#include <QRegion>
#include <QSize>
#include <QVariantMap>
#include <QRectF>
namespace DockGeometry {
enum Edge { Bottom, Top, Left, Right };
enum Alignment { Start, Center, End };
enum Visibility { AlwaysVisible, AutoHide, DodgeWindows, WindowsGoBelow };
QMargins alignmentMargins(const QSize &screen, const QSize &size, Edge edge, Alignment alignment, int margin);
QRect surface(const QRect &screen, const QSize &size, Edge edge, Alignment alignment = Center);
QPainterPath capsule(const QRectF &rect, qreal radius);
QPainterPath capsule(const QRectF &rect, const QList<qreal> &corners, bool vertical);
QVariantMap capsuleDrawing(QSizeF size, const QList<qreal> &corners, bool vertical, qreal border);
QRegion inputRegion(const QRectF &capsuleRect, const QPainterPath &shape, const QList<QRectF> &icons, const QRect &bounds, Edge edge = Bottom);
}
