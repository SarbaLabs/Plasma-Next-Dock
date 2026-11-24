// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once
#include <QSortFilterProxyModel>
#include <QSet>
#include "modulemanager.h"

// The view uses visual rows; all KDE requests still use native model indices.
class TaskRows : public QSortFilterProxyModel
{
    Q_OBJECT
    Q_PROPERTY(QVariantList desktopIds MEMBER m_desktops NOTIFY desktopsChanged)
    Q_PROPERTY(QVariantMap activityNames MEMBER m_activities NOTIFY activitiesChanged)
public:
    explicit TaskRows(ModuleManager *modules);
    void setSourceModel(QAbstractItemModel *model) override;
    Q_INVOKABLE int nativeRow(int row) const { return mapToSource(index(row, 0)).row(); }
    Q_INVOKABLE int visualRow(int nativeRow) const;
    QHash<int, QByteArray> roleNames() const override;
    QVariant data(const QModelIndex &index, int role) const override;
Q_SIGNALS:
    void desktopsChanged();
    void activitiesChanged();
private:
    bool filterAcceptsRow(int row, const QModelIndex &parent) const override;
    bool lessThan(const QModelIndex &left, const QModelIndex &right) const override;
    bool pinned(const QModelIndex &index) const;
    void queueRefresh();
    void refresh();
    void applyEntries();
    ModuleManager *m_modules;
    QList<QMetaObject::Connection> m_connections;
    QHash<QPersistentModelIndex, QString> m_ids;
    QHash<QString, int> m_order;
    QHash<QByteArray, int> m_roles;
    QSet<int> m_candidateRoles;
    QVariantList m_desktops;
    QVariantMap m_activities;
    quint64 m_serial = 0;
    bool m_pending = false;
};
