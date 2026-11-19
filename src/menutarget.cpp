// SPDX-License-Identifier: GPL-2.0-or-later
#include "menutarget.h"
#include <KLocalizedString>
#include <KNotification>
#include <QAction>
#include <QDBusUnixFileDescriptor>
#include <QIcon>
#include <QSet>
#include <cerrno>
#include <csignal>
#include <sys/syscall.h>
#include <unistd.h>
void MenuTarget::bind(QAbstractItemModel *model, int row)
{
    if (m_model) disconnect(m_model, nullptr, this, nullptr);
    m_model = model;
    m_index = model ? model->index(row, 0) : QModelIndex();
    if (model) {
        connect(model, &QAbstractItemModel::dataChanged, this, &MenuTarget::refresh);
        connect(model, &QAbstractItemModel::rowsRemoved, this, &MenuTarget::refresh);
        connect(model, &QAbstractItemModel::rowsMoved, this, &MenuTarget::refresh);
        connect(model, &QAbstractItemModel::layoutChanged, this, &MenuTarget::refresh);
        connect(model, &QAbstractItemModel::modelReset, this, &MenuTarget::refresh);
        connect(model, &QObject::destroyed, this, &MenuTarget::refresh);
    }
    Q_EMIT changed();
}
void MenuTarget::refresh()
{
    Q_EMIT changed();
    if (!valid()) Q_EMIT invalidated();
}
QVariant MenuTarget::data(const QString &role) const
{
    if (!m_model || !valid()) return {};
    const auto roles = m_model->roleNames();
    for (auto it = roles.cbegin(); it != roles.cend(); ++it)
        if (it.value() == role.toUtf8()) return m_index.data(it.key());
    return {};
}

QVariantList MenuTarget::killActions(QObject *owner) const
{
    QVariantList actions;
    if (!owner || !valid()) return actions;
    const auto roles = m_model->roleNames();
    const int pidRole = roles.key("AppPid", -1);
    const int windowRole = roles.key("IsWindow", -1);
    const bool group = data("IsGroupParent").toBool();
    const int count = group ? m_model->rowCount(m_index) : 1;
    QSet<int> seen;
    for (int row = 0; row < count; ++row) {
        const QPersistentModelIndex window = group ? m_model->index(row, 0, m_index) : QModelIndex(m_index);
        const int pid = window.data(pidRole).toInt();
        if (!window.data(windowRole).toBool() || pid <= 1 || pid == getpid() || seen.contains(pid)) continue;
        QDBusUnixFileDescriptor handle;
        handle.giveFileDescriptor(syscall(SYS_pidfd_open, pid, 0));
        if (!handle.isValid() || syscall(SYS_pidfd_send_signal, handle.fileDescriptor(), 0, nullptr, 0) != 0) continue;
        seen.insert(pid);
        auto *action = new QAction(QIcon::fromTheme(QStringLiteral("process-stop")),
            i18n("%1 (PID %2)", window.data().toString().replace('&', "&&"), QString::number(pid)), owner);
        connect(action, &QAction::triggered, this, [this, target = m_index, window, group, pidRole, pid, handle] {
            if (!valid() || m_index != target || !window.isValid() || window.data(pidRole).toInt() != pid) return;
            if (group && window.parent() != target) return;
            if (syscall(SYS_pidfd_send_signal, handle.fileDescriptor(), SIGKILL, nullptr, 0) != 0 && errno != ESRCH)
                KNotification::event(KNotification::Error, i18n("Kill"), i18n("Could not force the application to quit."));
        });
        actions << QVariant::fromValue(action);
    }
    if (actions.size() == 1) actions.first().value<QAction *>()->setText(i18n("Kill"));
    return actions;
}
