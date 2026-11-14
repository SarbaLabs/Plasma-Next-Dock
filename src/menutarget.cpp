// SPDX-License-Identifier: GPL-2.0-or-later
#include "menutarget.h"
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
