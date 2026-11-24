// SPDX-License-Identifier: GPL-2.0-or-later
#include "modulemanager.h"
#include <QQmlComponent>
#include <QSet>

ModuleManager::ModuleManager(const ModuleCatalog &catalog) : m_catalog(catalog)
{
    static const int type = qmlRegisterType<DockModule>("org.sarbalabs.nextdock.modules", 1, 0, "DockModule");
    static const int taskType = qmlRegisterType<TaskModule>("org.sarbalabs.nextdock.modules", 1, 0, "TaskModule");
    Q_UNUSED(type);
    Q_UNUSED(taskType);
}

void ModuleManager::configure(QStringList enabled, const QVariantMap &settings)
{
    enabled.removeDuplicates();
    m_configuring = true;
    for (const auto &id : std::as_const(m_enabled)) {
        if (!enabled.contains(id)) delete m_instances.take(id);
    }
    for (const auto &id : std::as_const(enabled)) {
        const auto options = settings.value(id).toMap();
        if (auto *instance = m_instances.value(id)) {
            instance->setProperty("configuration", options);
            continue;
        }
        if (m_enabled.contains(id)) continue; // Retry a failed load only on reactivation.
        const auto package = m_catalog.constFind(id);
        if (package == m_catalog.cend()) {
            qWarning() << "Enabled dock module is unavailable:" << id;
            continue;
        }
        // A separate engine keeps dock controllers and other root context properties
        // out of the module API. It is created only for an enabled package.
        if (!m_engine) m_engine = std::make_unique<QQmlEngine>();
        QQmlComponent component(m_engine.get(), package->entryPoint, QQmlComponent::PreferSynchronous);
        std::unique_ptr<QObject> object(component.isReady()
            ? component.createWithInitialProperties({{"configuration", options}}) : nullptr);
        auto *instance = qobject_cast<DockModule *>(object.get());
        if (!instance) {
            qWarning().noquote() << "Ignoring dock module" << id << package->entryPoint
                << (component.isError() ? component.errorString() : QStringLiteral("expected a DockModule root"));
            continue;
        }
        object.release()->setParent(m_engine.get());
        m_instances.insert(id, instance);
        if (auto *tasks = qobject_cast<TaskModule *>(instance)) tasks->setCandidates(m_candidates);
        connect(instance, &DockModule::entriesChanged, this, &ModuleManager::refresh);
    }
    m_enabled = enabled;
    m_configuring = false;
    refresh();
}

void ModuleManager::setTaskCandidates(const QVariantList &value)
{
    if (m_candidates == value) return;
    m_candidates = value;
    for (auto *instance : std::as_const(m_instances))
        if (auto *tasks = qobject_cast<TaskModule *>(instance)) tasks->setCandidates(value);
}

void ModuleManager::refresh()
{
    if (m_configuring) return;
    QVariantList next;
    for (const auto &id : std::as_const(m_enabled)) {
        const auto *instance = m_instances.value(id);
        if (!instance) continue;
        QSet<QString> seen;
        for (const QVariant &value : instance->entries) {
            auto entry = value.toMap();
            const QString key = entry.value("id").toString();
            if (key.isEmpty() || seen.contains(key) || entry.value("icon").toString().isEmpty()
                || entry.value("name").toString().isEmpty()) {
                qWarning() << "Ignoring invalid or duplicate dock module entry:" << id << key;
                continue;
            }
            seen.insert(key);
            if (!qobject_cast<const TaskModule *>(instance)) entry.remove("taskRef");
            entry.insert("moduleId", id);
            next.append(entry);
        }
    }
    if (next == m_entries) return;
    m_entries = next;
    Q_EMIT entriesChanged();
}

static bool allowsAction(const QVariantList &actions, const QString &id)
{
    for (const auto &value : actions) {
        const auto action = value.toMap();
        if (!action.value("enabled", true).toBool()) continue;
        const auto children = action.value("children").toList();
        if (children.isEmpty() && action.value("id").toString() == id) return true;
        if (allowsAction(children, id)) return true;
    }
    return false;
}

bool ModuleManager::activate(const QString &moduleId, const QString &entryId)
{
    return trigger(moduleId, entryId, {});
}

bool ModuleManager::trigger(const QString &moduleId, const QString &entryId, const QString &actionId)
{
    auto *module = m_instances.value(moduleId);
    if (!module) return false;
    // Resolve against current entries: an open menu can outlive a removable item.
    for (const auto &value : std::as_const(m_entries)) {
        const auto entry = value.toMap();
        if (entry.value("moduleId") != moduleId || entry.value("id") != entryId) continue;
        if (!entry.value("enabled", true).toBool()) return false;
        if (actionId.isEmpty()) Q_EMIT module->activated(entryId);
        else if (allowsAction(entry.value("actions").toList(), actionId))
            Q_EMIT module->actionTriggered(entryId, actionId);
        else return false;
        return true;
    }
    return false;
}
