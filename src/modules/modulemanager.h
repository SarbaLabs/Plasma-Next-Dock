// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once
#include "modulecatalog.h"
#include <QQmlEngine>
#include <memory>

// The only host-provided QML type visible inside the provider engine.
class DockModule : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantList entries MEMBER entries NOTIFY entriesChanged)
    Q_PROPERTY(QVariantMap configuration MEMBER configuration NOTIFY configurationChanged)
public:
    QVariantList entries;
    QVariantMap configuration;
Q_SIGNALS:
    void entriesChanged();
    void configurationChanged();
    void preferencesEdited(const QVariantMap &changes);
    void documentsDropped(const QString &entryId, const QList<QUrl> &urls);
    void activated(const QString &entryId);
    void actionTriggered(const QString &entryId, const QString &actionId);
};

// Read-only task snapshots are opt-in. Providers never receive KDE model objects.
class TaskModule : public DockModule
{
    Q_OBJECT
    Q_PROPERTY(QVariantList candidates READ candidates NOTIFY candidatesChanged)
public:
    QVariantList candidates() const { return m_candidates; }
    void setCandidates(const QVariantList &value) {
        if (m_candidates == value) return;
        m_candidates = value;
        Q_EMIT candidatesChanged();
    }
Q_SIGNALS:
    void candidatesChanged();
private:
    QVariantList m_candidates;
};

class ModuleManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantList entries READ entries NOTIFY entriesChanged)
public:
    explicit ModuleManager(const ModuleCatalog &catalog);
    void configure(QStringList enabled, const QVariantMap &settings);
    QVariantList entries() const { return m_entries; }
    void setTaskCandidates(const QVariantList &value);
    QVariantMap metadata(const QString &id) const { return m_catalog.value(id).metadata; }
    bool loaded(const QString &id) const { return m_instances.contains(id); }
    Q_INVOKABLE bool dropDocuments(const QString &moduleId, const QString &entryId, const QList<QUrl> &urls);
    Q_INVOKABLE bool activate(const QString &moduleId, const QString &entryId);
    Q_INVOKABLE bool trigger(const QString &moduleId, const QString &entryId, const QString &actionId);
Q_SIGNALS:
    void entriesChanged();
    void preferencesEdited(const QString &moduleId, const QVariantMap &changes);
private:
    void refresh();
    ModuleCatalog m_catalog;
    std::unique_ptr<QQmlEngine> m_engine;
    QHash<QString, DockModule *> m_instances;
    QStringList m_enabled;
    QVariantList m_candidates;
    QVariantList m_entries;
    bool m_configuring = false;
};
