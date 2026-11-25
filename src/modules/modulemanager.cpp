// SPDX-License-Identifier: GPL-2.0-or-later
#include "modulemanager.h"
#include <QQmlComponent>
#include <QQmlContext>
#include <KLocalizedQmlContext>
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
        if (!m_engine) {
            m_engine = std::make_unique<QQmlEngine>();
            auto *strings = new KLocalizedQmlContext(m_engine.get());
            strings->setTranslationDomain(QStringLiteral("plasma-next-dock"));
            m_engine->rootContext()->setContextObject(strings);
        }
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
        connect(instance, &DockModule::preferencesEdited, this, [this, id](const QVariantMap &changes) {
            Q_EMIT preferencesEdited(id, changes);
        });
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
            entry.insert("directoryInsertion", instance->acceptsDirectoryDrops && entry.value("reorderable").toBool());
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

bool ModuleManager::moveEntry(const QString &moduleId, const QString &entryId, const QString &destinationId)
{
    auto *module = m_instances.value(moduleId);
    if (!module || entryId == destinationId) return false;
    bool source = false, destination = false;
    for (const auto &value : std::as_const(m_entries)) {
        const auto entry = value.toMap();
        if (entry.value("moduleId") != moduleId || !entry.value("reorderable").toBool()) continue;
        source |= entry.value("id") == entryId;
        destination |= entry.value("id") == destinationId;
    }
    if (!source || !destination) return false;
    Q_EMIT module->moveRequested(entryId, destinationId);
    return true;
}

// Use the first enabled receiver in dock order, including empty providers.
DockModule *ModuleManager::directoryReceiver() const
{
    for (const auto &id : m_enabled) {
        auto *module = m_instances.value(id);
        if (module && module->acceptsDirectoryDrops) return module;
    }
    return nullptr;
}

bool ModuleManager::dropDirectories(const QList<QUrl> &urls)
{
    auto *module = directoryReceiver();
    if (!module || urls.isEmpty()) return false;
    // Acceptance means delivery. A provider may already contain every shortcut.
    Q_EMIT module->directoriesDropped(urls, {});
    return true;
}

// Resolve the saved boundary again: a module or shortcut can disappear during a drag.
bool ModuleManager::insertDirectories(const QString &moduleId, const QString &beforeId, const QList<QUrl> &urls)
{
    auto *module = m_instances.value(moduleId);
    if (!module || !module->acceptsDirectoryDrops || urls.isEmpty()) return false;
    for (const auto &value : module->entries) {
        const auto entry = value.toMap();
        if ((beforeId.isEmpty() || entry.value("id") == beforeId) && entry.value("reorderable").toBool()) {
            Q_EMIT module->directoriesDropped(urls, beforeId);
            return true;
        }
    }
    return false;
}

bool ModuleManager::dropDocuments(const QString &moduleId, const QString &entryId, const QList<QUrl> &urls)
{
    auto *module = m_instances.value(moduleId);
    if (!module || urls.isEmpty()) return false;
    for (const auto &value : std::as_const(m_entries)) {
        const auto entry = value.toMap();
        if (entry.value("moduleId") == moduleId && entry.value("id") == entryId
            && entry.value("enabled", true).toBool() && entry.value("acceptsDocuments").toBool()) {
            Q_EMIT module->documentsDropped(entryId, urls);
            return true;
        }
    }
    return false;
}
