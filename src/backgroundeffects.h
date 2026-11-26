// SPDX-FileCopyrightText: 2024 Matt Anis
// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once
#include <QObject>
#include <QPointer>
#include <QQuickWindow>
#include <QRegion>
#include <QPainterPath>
#include <QVariantMap>

// One effect owner for the standalone window; all calls stay on the GUI thread.
class BackgroundEffects : public QObject
{
    Q_OBJECT
public:
    explicit BackgroundEffects(QQuickWindow *window, QObject *parent = nullptr);
    ~BackgroundEffects() override;
    void configure(const QVariantMap &options);
    void setGeometry(const QPainterPath &path);
protected:
    bool eventFilter(QObject *object, QEvent *event) override;
    virtual void writeEffects(bool enabled, const QRegion &region);
private:
    void schedule(bool restore = false);
    void apply();
    void clear();
    QPointer<QQuickWindow> m_window;
    QPainterPath m_capsule;
    QRegion m_lastRegion;
    int m_borderWidth = 0;
    bool m_enabled = false, m_applied = false, m_queued = false;
    bool m_restore = true, m_surfaceDestroyed = false;
};
