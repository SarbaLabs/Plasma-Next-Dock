// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once
#include <QAbstractItemModel>
#include <QPersistentModelIndex>
#include <QPointer>

// A popup can outlive the delegate or its row. Never dispatch to a recycled row.
class MenuTarget : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QModelIndex index READ index NOTIFY changed)
    Q_PROPERTY(bool valid READ valid NOTIFY changed)
public:
    using QObject::QObject;
    QModelIndex index() const { return m_index; }
    bool valid() const { return m_index.isValid(); }
    Q_INVOKABLE void bind(QAbstractItemModel *model, int row);
    Q_INVOKABLE QVariantList killActions(QObject *owner) const;
    Q_INVOKABLE QVariant data(const QString &role) const;
Q_SIGNALS:
    void changed();
    void invalidated();
private:
    void refresh();
    QPointer<QAbstractItemModel> m_model;
    QPersistentModelIndex m_index;
};
