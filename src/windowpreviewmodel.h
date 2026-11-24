// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once
#include <QAbstractListModel>
#include <QPersistentModelIndex>
#include <QPointer>

// Only the selected task's leaves are exposed. Persistent indexes survive moves
// and prevent a disappearing preview from activating a replacement window.
class WindowPreviewModel : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(int count READ count NOTIFY countChanged)
public:
    enum Role { Title = Qt::UserRole + 1, Icon, WindowId, Minimized, Active, Closable };
    using QAbstractListModel::QAbstractListModel;
    ~WindowPreviewModel() override;
    Q_INVOKABLE void highlight(const QString &id);
    int count() const { return m_windows.size(); }
    int rowCount(const QModelIndex &parent = {}) const override { return parent.isValid() ? 0 : count(); }
    QHash<int, QByteArray> roleNames() const override;
    QVariant data(const QModelIndex &index, int role) const override;
    Q_INVOKABLE void select(QAbstractItemModel *source, int row);
    Q_INVOKABLE void clear();
    Q_INVOKABLE void activate(int row);
    Q_INVOKABLE void close(int row);
Q_SIGNALS:
    void countChanged();
    void targetGone();
private:
    QVariant value(const QModelIndex &index, const QByteArray &name) const;
    void refresh();
    void schedule();
    void request(int row, const char *method);
    QPointer<QAbstractItemModel> m_source;
    QPersistentModelIndex m_target;
    QList<QPersistentModelIndex> m_windows;
    QString m_highlightId;
    bool m_trackingTarget = false;
    bool m_pending = false;
};
