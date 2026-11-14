// SPDX-FileCopyrightText: 2024 Matt Anis
// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once
#include <QObject>
#include <QPointer>
#include <QQuickWindow>
#include <QRegion>
#include <QVariantMap>

// One effect owner for the standalone window; all calls stay on the GUI thread.
class BackgroundEffects : public QObject
{
    Q_OBJECT
public:
    explicit BackgroundEffects(QQuickWindow *window, QObject *parent = nullptr);
    ~BackgroundEffects() override;
    void configure(const QVariantMap &options);
    void setGeometry(QRectF capsule, qreal radius);
protected:
    bool eventFilter(QObject *object, QEvent *event) override;
    virtual void writeEffects(bool enabled, const QRegion &region, qreal contrast, qreal brightness, qreal saturation);
private:
    void schedule(bool restore = false);
    void apply();
    void clear();
    QPointer<QQuickWindow> m_window;
    QRectF m_capsule;
    qreal m_radius = 0;
    qreal m_contrast = 1, m_brightness = 1, m_saturation = 1.3;
    QRegion m_lastRegion;
    bool m_enabled = false, m_applied = false, m_queued = false;
    bool m_restore = true, m_surfaceDestroyed = false, m_parametersChanged = false;
};
