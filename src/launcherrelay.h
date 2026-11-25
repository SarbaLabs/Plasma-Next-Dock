// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once
#include <QObject>
#include <QStringList>
#include <QTimer>
#include <KDirWatch>

class LauncherRelay : public QObject
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.sarbalabs.PlasmaNextDock.Launcher")
public:
    void start();
    void setOutputs(QStringList names);
public Q_SLOTS:
    void Activate();
Q_SIGNALS:
    void requested(const QString &output);
private Q_SLOTS:
    void schedule();
private:
    void synchronize(bool stopping = false);
    QStringList m_outputs;
    int m_retries = 0;
    KDirWatch m_watcher;
    QTimer m_delay;
    bool m_running = false;
};
