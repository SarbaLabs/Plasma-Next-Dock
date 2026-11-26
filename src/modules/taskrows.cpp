// SPDX-License-Identifier: GPL-2.0-or-later
#include "taskrows.h"
#include <QDateTime>
#include <QIcon>
#include <algorithm>

static constexpr int nativeRowRole = Qt::UserRole + 65536;

static constexpr int moduleEntryRole = nativeRowRole + 1;
static constexpr int boundaryRole = nativeRowRole + 2;
static constexpr int zoneRole = nativeRowRole + 3;

static QString entryKey(const QVariantMap &entry)
{
    const auto ref = entry.value("taskRef").toString();
    return ref.isEmpty() ? entry.value("moduleId").toString() + '/' + entry.value("id").toString() : ref;
}

TaskRows::TaskRows(ModuleManager *modules) : m_modules(modules)
{
    connect(modules, &ModuleManager::entriesChanged, this, &TaskRows::applyEntries);
    connect(this, &TaskRows::desktopsChanged, this, &TaskRows::queueRefresh);
    connect(this, &TaskRows::activitiesChanged, this, &TaskRows::queueRefresh);
    m_generic.setColumnCount(1);
    m_join.addSourceModel(&m_generic);
    connect(this, &QAbstractItemModel::rowsInserted, this, &TaskRows::queueBoundaries);
    connect(this, &QAbstractItemModel::rowsRemoved, this, &TaskRows::queueBoundaries);
    connect(this, &QAbstractItemModel::layoutChanged, this, &TaskRows::queueBoundaries);
    sort(0);
}

TaskRows::~TaskRows()
{
    QSortFilterProxyModel::setSourceModel(nullptr);
}

void TaskRows::setTaskModel(QAbstractItemModel *model)
{
    if (model == m_tasks) return;
    QSortFilterProxyModel::setSourceModel(nullptr);
    if (m_tasks) m_join.removeSourceModel(m_tasks);
    m_tasks = model;
    for (const auto &connection : std::as_const(m_connections)) disconnect(connection);
    m_connections.clear();
    m_ids.clear();
    m_roles.clear();
    m_candidateRoles = {Qt::DisplayRole, Qt::DecorationRole};
    if (model) {
        m_join.addSourceModel(model);
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
    QSortFilterProxyModel::setSourceModel(model ? &m_join : nullptr);
    Q_EMIT taskModelChanged();
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
    for (int row = 0; m_tasks && row < m_tasks->rowCount(); ++row) {
        const auto index = m_tasks->index(row, 0);
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
    QHash<QString, QString> owners;
    QList<QVariantMap> generic;
    for (const auto &value : m_modules->entries()) {
        const auto entry = value.toMap();
        const auto key = entryKey(entry);
        if (order.contains(key)) continue;
        order.insert(key, order.size());
        owners.insert(key, entry.value("moduleId").toString());
        if (entry.value("taskRef").toString().isEmpty()) generic.append(entry);
    }
    const bool reordered = order != m_order || owners != m_owners;
    m_order.swap(order);
    m_owners.swap(owners);
    // Generic entries have no TasksModel index. Keep regular task delegates
    // alive when a provider only changes its label, icon or action state.
    while (m_generic.rowCount() > generic.size()) m_generic.removeRow(m_generic.rowCount()-1);
    for (int i = 0; i < generic.size(); ++i) {
        if (i == m_generic.rowCount()) {
            auto *item = new QStandardItem;
            item->setData(generic[i], moduleEntryRole);
            m_generic.appendRow(item);
        } else m_generic.setData(m_generic.index(i, 0), generic[i], moduleEntryRole);
    }
    if (reordered) { invalidate(); queueBoundaries(); }
}

void TaskRows::setLeadingModules(const QStringList &modules)
{
    if (m_leading == modules) return;
    m_leading = modules;
    invalidate();
    queueBoundaries();
}

QString TaskRows::keyFor(const QModelIndex &source) const
{
    return source.model() == &m_generic ? entryKey(source.data(moduleEntryRole).toMap()) : m_ids.value(source);
}

int TaskRows::zone(const QModelIndex &source) const
{
    if (source.model() != &m_generic && pinned(source)) return 0;
    return m_leading.contains(m_owners.value(keyFor(source))) ? -1 : 1;
}

bool TaskRows::filterAcceptsRow(int row, const QModelIndex &parent) const
{
    if (parent.isValid()) return false;
    const auto source = m_join.mapToSource(m_join.index(row, 0));
    return source.model() == &m_generic || pinned(source) || m_order.contains(keyFor(source));
}

bool TaskRows::lessThan(const QModelIndex &left, const QModelIndex &right) const
{
    const auto a = m_join.mapToSource(left), b = m_join.mapToSource(right);
    const int az = zone(a), bz = zone(b);
    if (az != bz) return az < bz;
    if (az == 0) return a.row() < b.row();
    return m_order.value(keyFor(a)) < m_order.value(keyFor(b));
}

int TaskRows::nativeRow(int row) const
{
    const auto source = m_join.mapToSource(mapToSource(index(row, 0)));
    return source.model() == m_tasks ? source.row() : -1;
}

QVariantMap TaskRows::settingsForRow(int row) const
{
    const auto source = m_join.mapToSource(mapToSource(index(row, 0)));
    if (!source.isValid() || zone(source) == 0) return {};
    return m_modules->metadata(m_owners.value(keyFor(source)));
}

int TaskRows::visualRow(int nativeRow) const
{
    return m_tasks ? mapFromSource(m_join.mapFromSource(m_tasks->index(nativeRow, 0))).row() : -1;
}

QHash<int, QByteArray> TaskRows::roleNames() const
{
    auto roles = m_tasks ? m_tasks->roleNames() : QAbstractItemModel::roleNames();
    roles.insert(nativeRowRole, "nativeTaskRow");
    roles.insert(moduleEntryRole, "moduleEntry");
    roles.insert(zoneRole, "dockZone");
    roles.insert(boundaryRole, "separatorAfter");
    return roles;
}

void TaskRows::queueBoundaries()
{
    if (m_boundariesPending) return;
    m_boundariesPending = true;
    QMetaObject::invokeMethod(this, [this] {
        m_boundariesPending = false;
        if (rowCount()) Q_EMIT dataChanged(index(0, 0), index(rowCount()-1, 0), {boundaryRole, nativeRowRole, zoneRole});
    }, Qt::QueuedConnection);
}

QVariant TaskRows::data(const QModelIndex &idx, int role) const
{
    if (!idx.isValid()) return {};
    const auto source = m_join.mapToSource(mapToSource(idx));
    if (role == zoneRole) return zone(source);
    if (role == nativeRowRole) return source.model() == m_tasks ? source.row() : -1;
    if (role == boundaryRole) {
        if (idx.row()+1 >= rowCount()) return false;
        const auto next = m_join.mapToSource(mapToSource(index(idx.row()+1, 0)));
        return (zone(source) == 0) != (zone(next) == 0);
    }
    if (source.model() == &m_generic) {
        const auto entry = source.data(moduleEntryRole).toMap();
        if (role == moduleEntryRole) return entry;
        if (role == Qt::DisplayRole) return entry.value("name");
        if (role == Qt::DecorationRole) return entry.value("icon");
        return {};
    }
    return role == moduleEntryRole ? QVariant{} : source.data(role);
}
