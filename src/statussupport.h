// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once
#include <QObject>
#include <QFile>
#include <QCoreApplication>
#include <QDir>
#include <QPluginLoader>
#include <memory>
// Focused helper, without the task manager Backend's global shortcuts.
class StatusSupport : public QObject
{
    Q_OBJECT
public:
    using QObject::QObject;
    // New Plasma applets use QT_NO_PLUGIN QML modules. Loading the installed
    // applet library registers their types; never call instance() or create an
    // Applet/Backend. Registered QML code must remain loaded for the process.
    Q_INVOKABLE bool prepareSmartLauncherModule() {
        if (m_attempted) return m_plugin && m_plugin->isLoaded();
        m_attempted = true;
        for (const auto &base : QCoreApplication::libraryPaths()) {
            const auto path = QDir(base).filePath(QStringLiteral("plasma/applets/org.kde.plasma.taskmanager.so"));
            if (!QFile::exists(path)) continue;
            auto plugin = std::make_unique<QPluginLoader>(path);
            plugin->setLoadHints(QLibrary::PreventUnloadHint);
            if (plugin->load()) {
                m_plugin = std::move(plugin);
                m_error.clear();
                return true;
            }
            m_error += path + QStringLiteral(": ") + plugin->errorString() + QLatin1Char('\n');
        }
        if (m_error.isEmpty()) m_error = QStringLiteral("No taskmanager applet library in Qt plugin paths (legacy Plasma may not need one)");
        return false;
    }
    Q_INVOKABLE QString smartLauncherLoadError() const { return m_error; }
    Q_INVOKABLE int parentPid(int pid) const {
        if (pid <= 0) return -1;
        QFile file(QStringLiteral("/proc/%1/stat").arg(pid));
        if (!file.open(QIODevice::ReadOnly)) return -1;
        const auto stat = file.readAll();
        const int end = stat.lastIndexOf(')');
        if (end < 0) return -1;
        const auto fields = stat.mid(end + 2).split(' ');
        bool ok = false;
        const int parent = fields.size() > 1 ? fields[1].toInt(&ok) : -1;
        return ok ? parent : -1;
    }
private:
    bool m_attempted = false;
    QString m_error;
    std::unique_ptr<QPluginLoader> m_plugin;
};
