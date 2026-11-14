// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once
#include <QObject>
#include <QFile>
// Focused helper, without the task manager Backend's global shortcuts.
class StatusSupport : public QObject
{
    Q_OBJECT
public:
    using QObject::QObject;
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
};
