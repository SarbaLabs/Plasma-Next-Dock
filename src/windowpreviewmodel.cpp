// SPDX-License-Identifier: GPL-2.0-or-later
#include "windowpreviewmodel.h"
QHash<int, QByteArray> WindowPreviewModel::roleNames() const
{
    return {{Title,"title"},{Icon,"icon"},{WindowId,"windowId"},{Minimized,"minimized"},{Active,"active"},{Closable,"closable"}};
}
QVariant WindowPreviewModel::value(const QModelIndex &index, const QByteArray &name) const
{
    if (!m_source || !index.isValid()) return {};
    const auto roles = m_source->roleNames();
    for (auto it = roles.cbegin(); it != roles.cend(); ++it)
        if (it.value() == name) return index.data(it.key());
    return {};
}
QVariant WindowPreviewModel::data(const QModelIndex &index, int role) const
{
    if (index.row() < 0 || index.row() >= count()) return {};
    const auto window = m_windows[index.row()];
    if (!window.isValid()) return {};
    switch (role) {
    case Title: return value(window, "display");
    case Icon: return value(window, "decoration");
    case Minimized: return value(window, "IsMinimized");
    case Active: return value(window, "IsActive");
    case Closable: return value(window, "IsClosable");
    case WindowId: {
        const auto ids = value(window, "WinIdList").toList();
        return ids.isEmpty() ? QString() : ids.first().toString();
    }
    default: return {};
    }
}
void WindowPreviewModel::select(QAbstractItemModel *source, int row)
{
    if (m_source) disconnect(m_source, nullptr, this, nullptr);
    m_source = source;
    m_target = source ? source->index(row, 0) : QModelIndex();
    if (source) {
        connect(source, &QAbstractItemModel::dataChanged, this, &WindowPreviewModel::schedule);
        connect(source, &QAbstractItemModel::rowsInserted, this, &WindowPreviewModel::schedule);
        connect(source, &QAbstractItemModel::rowsRemoved, this, &WindowPreviewModel::schedule);
        connect(source, &QAbstractItemModel::rowsMoved, this, &WindowPreviewModel::schedule);
        connect(source, &QAbstractItemModel::layoutChanged, this, &WindowPreviewModel::schedule);
        connect(source, &QAbstractItemModel::modelReset, this, &WindowPreviewModel::schedule);
        connect(source, &QObject::destroyed, this, &WindowPreviewModel::schedule);
    }
    refresh();
}
void WindowPreviewModel::clear() { select(nullptr, -1); }
void WindowPreviewModel::schedule()
{
    if (m_pending) return;
    m_pending = true;
    QMetaObject::invokeMethod(this, [this] { m_pending = false; refresh(); }, Qt::QueuedConnection);
}
void WindowPreviewModel::refresh()
{
    QList<QPersistentModelIndex> windows;
    if (m_source && m_target.isValid()) {
        if (value(m_target, "IsGroupParent").toBool()) {
            for (int i = 0; i < m_source->rowCount(m_target); ++i) {
                const auto child = m_source->index(i, 0, m_target);
                if (value(child, "IsWindow").toBool()) windows << child;
            }
        } else if (value(m_target, "IsWindow").toBool()) {
            windows << m_target;
        }
    }
    if (windows != m_windows) {
        beginResetModel(); m_windows = windows; endResetModel();
        Q_EMIT countChanged();
    } else if (!windows.isEmpty()) {
        Q_EMIT dataChanged(index(0), index(count() - 1));
    }
    if (!m_target.isValid()) Q_EMIT targetGone();
}
void WindowPreviewModel::request(int row, const char *method)
{
    if (!m_source || row < 0 || row >= count() || !m_windows[row].isValid()) return;
    const QModelIndex index = m_windows[row];
    QMetaObject::invokeMethod(m_source, method, Qt::DirectConnection, Q_ARG(QModelIndex, index));
}
void WindowPreviewModel::activate(int row) { request(row, "requestActivate"); }
void WindowPreviewModel::close(int row)
{
    if (row >= 0 && row < count() && value(m_windows[row], "IsClosable").toBool()) request(row, "requestClose");
}
