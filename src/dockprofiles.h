// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once
#include "settings.h"
#include <QList>

class DockProfiles : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QStringList labels READ labels NOTIFY listChanged)
    Q_PROPERTY(int selectedIndex READ selectedIndex NOTIFY selectionChanged)
public:
    DockProfiles(const QString &file, bool persistent, const QString &loginTemplate);
    QStringList labels() const;
    int selectedIndex() const { return m_profiles.indexOf(m_current); }
    DockSettings *current() const { return m_current; }
    const QList<DockSettings *> &profiles() const { return m_profiles; }
    Q_INVOKABLE void select(int index);
    Q_INVOKABLE bool add();
    Q_INVOKABLE bool removeSelected();
    Q_INVOKABLE bool positionAvailable(const QString &screen, int edge) const;
    void setOutputs(const QStringList &outputs, const QString &primary);
    QString assignedOutput(DockSettings *profile) const;
Q_SIGNALS:
    void listChanged();
    void selectionChanged();
    void openRequested();
    void profileChanged();
private:
    DockSettings *create(const QString &id);
    bool storeIds(const QStringList &ids);
    bool occupied(const QString &screen, int edge, DockSettings *except) const;
    const QString m_file;
    const bool m_persistent;
    const QString m_loginTemplate;
    QStringList m_ids;
    QList<DockSettings *> m_profiles;
    DockSettings *m_current = nullptr;
    QStringList m_outputs;
    QString m_primary;
};
