// SPDX-License-Identifier: GPL-2.0-or-later
#include "modulecatalog.h"
#include <QDebug>
#include <QDir>
#include <QJsonDocument>
#include <QJsonObject>
#include <QLocale>
#include <QRegularExpression>
#include <QSet>

static QString localized(const QJsonObject &manifest, const QString &key)
{
    // Standard Qt locale preferences include both region-specific and base languages.
    const auto translations = manifest.value(key + "Translations").toObject();
    for (const QString &language : QLocale().uiLanguages()) {
        const auto text = translations.value(language).toString();
        if (!text.trimmed().isEmpty()) return text;
    }
    return manifest.value(key).toString();
}

ModuleCatalog discoverModules(const QStringList &dataRoots)
{
    ModuleCatalog catalog;
    QSet<QString> claimed;
    static const QRegularExpression validId(QStringLiteral("^[a-z0-9]+(?:[.-][a-z0-9]+)*$"));
    for (const auto &root : dataRoots) {
        const QDir modules(QDir(root).filePath("plasma-next-dock/modules"));
        for (const auto &id : modules.entryList(QDir::Dirs | QDir::NoDotAndDotDot, QDir::Name)) {
            if (claimed.contains(id)) continue;
            // An invalid user override must not silently run another implementation.
            claimed.insert(id);
            const QDir package(modules.filePath(id));
            QFile file(package.filePath("metadata.json"));
            QJsonParseError error;
            const auto manifest = file.open(QIODevice::ReadOnly)
                ? QJsonDocument::fromJson(file.readAll(), &error).object() : QJsonObject{};
            QString problem;
            if (!file.isOpen()) problem = file.errorString();
            else if (error.error != QJsonParseError::NoError) problem = error.errorString();
            else if (!validId.match(id).hasMatch() || manifest.value("id").toString() != id)
                problem = "manifest id must match the package directory";
            else if (manifest.value("apiVersion").toDouble(-1) != 1)
                problem = "unsupported apiVersion (expected 1)";
            else if (manifest.value("name").toString().trimmed().isEmpty()
                     || manifest.value("description").toString().trimmed().isEmpty()
                     || manifest.value("version").toString().trimmed().isEmpty())
                problem = "name, description and version must be non-empty strings";
            else if (!QFileInfo(package.filePath("Main.qml")).isFile()) problem = "missing Main.qml";
            if (!problem.isEmpty()) {
                qWarning().noquote() << "Ignoring dock module" << package.path() << problem;
                continue;
            }
            QVariantMap metadata{{"id", id}, {"name", localized(manifest, "name")},
                {"description", localized(manifest, "description")}, {"version", manifest.value("version").toString()},
                {"apiVersion", 1}};
            const auto popup = package.filePath("Popup.qml");
            if (QFileInfo(popup).isFile()) metadata.insert("popupUrl", QUrl::fromLocalFile(popup));
            const auto settings = package.filePath("Settings.qml");
            if (QFileInfo(settings).isFile()) metadata.insert("settingsUrl", QUrl::fromLocalFile(settings));
            catalog.insert(id, {metadata, QUrl::fromLocalFile(package.filePath("Main.qml"))});
        }
    }
    return catalog;
}
