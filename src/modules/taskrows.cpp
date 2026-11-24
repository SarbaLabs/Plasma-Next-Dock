// SPDX-License-Identifier: GPL-2.0-or-later
#include "taskrows.h"
#include <QDateTime>
#include <QIcon>
#include <algorithm>

static constexpr int nativeRowRole = Qt::UserRole + 65536;

TaskRows::TaskRows(ModuleManager *modules) : m_modules(modules)
{
    connect(modules, &ModuleManager::entriesChanged, this, &TaskRows::applyEntries);
    connect(this, &TaskRows::desktopsChanged, this, &TaskRows::queueRefresh);
    connect(this, &TaskRows::activitiesChanged, this, &TaskRows::queueRefresh);
    sort(0);
}

void TaskRows::setSourceModel(QAbstractItemModel *model)
{
    if (model == sourceModel()) return;
    for (const auto &connection : std::as_const(m_connections)) disconnect(connection);
    m_connections.clear();
    m_ids.clear();
    m_roles.clear();
    m_candidateRoles = {Qt::DisplayRole, Qt::DecorationRole};
    if (model) {
        const auto roles = model->roleNames();
        for (auto it = roles.begin(); it != roles.end(); ++it) m_roles.insert(it.value(), it.key());
        for (const auto key : {"IsLauncher", "HasLauncher", "AppName", "AppId", "Activities",
                               "VirtualDesktops", "IsOnAllVirtualDesktops", "LastActivated"}) {
            if (m_roles.contains(key)) m_candidateRoles.insert(m_roles.value(key));
        }
        m_connections << connect(model, &QAbstractItemModel::rowsInserted, this, &TaskRows::queueRefresh)
            << connect(model, &QAbstractItemModel::rowsRemoved, this, &TaskRows::queueRefresh)
            << connect(model, &QAbstractItemModel::rowsMoved, this, &TaskRows::queueRefresh)
            << connect(model, &QAbstractItemModel::modelReset, this, &TaskRows::queueRefresh)
            << connect(model, &QAbstractItemModel::layoutChanged, this, &TaskRows::queueRefresh)
            << connect(model, &QAbstractItemModel::dataChanged, this,
                [this](const QModelIndex &first, const QModelIndex &, const QList<int> &roles) {
                    // Geometry, hover and badge changes do not change module membership or order.
                    if (!first.parent().isValid() && (roles.isEmpty() || std::any_of(roles.begin(), roles.end(),
                        [this](int role) { return m_candidateRoles.contains(role); }))) queueRefresh();
                });
    }
    QSortFilterProxyModel::setSourceModel(model);
    queueRefresh();
}

bool TaskRows::pinned(const QModelIndex &index) const
{
    return index.data(m_roles.value("IsLauncher", -1)).toBool() || index.data(m_roles.value("HasLauncher", -1)).toBool();
}

void TaskRows::queueRefresh()
{
    if (m_pending) return;
    m_pending = true;
    QMetaObject::invokeMethod(this, &TaskRows::refresh, Qt::QueuedConnection);
}

void TaskRows::refresh()
{
    m_pending = false;
    QHash<QPersistentModelIndex, QString> ids;
    QVariantList candidates;
    for (int row = 0; sourceModel() && row < sourceModel()->rowCount(); ++row) {
        const auto index = sourceModel()->index(row, 0);
        if (pinned(index)) continue;
        auto id = m_ids.value(index);
        if (id.isEmpty()) id = QString::number(++m_serial);
        ids.insert(index, id);
        const auto role = [&](const char *key) { return index.data(m_roles.value(key, -1)); };
        const auto title = index.data().toString();
        QString name = role("AppName").toString();
        if (name.isEmpty()) name = title;
        if (name.isEmpty()) name = role("AppId").toString();
        QString icon = qvariant_cast<QIcon>(index.data(Qt::DecorationRole)).name();
        if (icon.isEmpty()) icon = "application-x-executable";
        int desktop = m_desktops.size();
        for (const auto &value : role("VirtualDesktops").toList()) {
            const int pos = m_desktops.indexOf(value);
            if (pos >= 0) desktop = std::min(desktop, pos);
        }
        QStringList activities;
        for (const auto &activity : role("Activities").toStringList())
            activities << m_activities.value(activity, activity).toString();
        activities.sort();
        const auto activated = role("LastActivated").toDateTime();
        candidates.append(QVariantMap{{"id", id}, {"name", name.isEmpty() ? icon : name}, {"icon", icon},
            {"title", title}, {"desktop", role("IsOnAllVirtualDesktops").toBool() ? -1 : desktop},
            {"activity", activities.join(", ")}, {"lastActivated", activated.isValid() ? activated.toMSecsSinceEpoch() : 0}});
    }
    m_ids.swap(ids);
    m_modules->setTaskCandidates(candidates);
    // Source rows may have shifted without changing the module entry order.
    if (rowCount()) Q_EMIT dataChanged(index(0, 0), index(rowCount()-1, 0), {nativeRowRole});
}

void TaskRows::applyEntries()
{
    QHash<QString, int> order;
    for (const auto &value : m_modules->entries()) {
        const QString ref = value.toMap().value("taskRef").toString();
        if (!ref.isEmpty() && !order.contains(ref)) order.insert(ref, order.size());
    }
    if (order == m_order) return;
    m_order.swap(order);
    invalidate();
}

bool TaskRows::filterAcceptsRow(int row, const QModelIndex &parent) const
{
    if (parent.isValid()) return false;
    const auto index = sourceModel()->index(row, 0);
    return pinned(index) || m_order.contains(m_ids.value(index));
}

bool TaskRows::lessThan(const QModelIndex &left, const QModelIndex &right) const
{
    const bool leftPinned = pinned(left), rightPinned = pinned(right);
    if (leftPinned != rightPinned) return leftPinned;
    if (leftPinned) return left.row() < right.row();
    return m_order.value(m_ids.value(left)) < m_order.value(m_ids.value(right));
}

QVariantMap TaskRows::settingsForRow(int row) const
{
    const auto source = mapToSource(index(row, 0));
    if (!source.isValid() || pinned(source)) return {};
    const auto ref = m_ids.value(source);
    if (ref.isEmpty()) return {};
    // The first provider claiming a task supplies its visible slot and menu.
    for (const auto &value : m_modules->entries()) {
        const auto entry = value.toMap();
        if (entry.value("taskRef").toString() == ref)
            return m_modules->metadata(entry.value("moduleId").toString());
    }
    return {};
}

int TaskRows::visualRow(int nativeRow) const
{
    return sourceModel() ? mapFromSource(sourceModel()->index(nativeRow, 0)).row() : -1;
}

QHash<int, QByteArray> TaskRows::roleNames() const
{
    auto roles = QSortFilterProxyModel::roleNames();
    roles.insert(nativeRowRole, "nativeTaskRow");
    return roles;
}

QVariant TaskRows::data(const QModelIndex &index, int role) const
{
    if (role == nativeRowRole) return mapToSource(index).row();
    return QSortFilterProxyModel::data(index, role);
}
