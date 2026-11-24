// SPDX-License-Identifier: GPL-2.0-or-later
#include "launcherresolver.h"
#include <KApplicationTrader>
#include <KService>
#include <QFileInfo>
#include <QCollator>
#include <algorithm>

QVariantList LauncherResolver::applications() const
{
    auto services = KApplicationTrader::query([](const KService::Ptr &s) {
        return s->isApplication() && !s->noDisplay() && s->showInCurrentDesktop();
    });
    QCollator collator;
    collator.setCaseSensitivity(Qt::CaseInsensitive);
    std::sort(services.begin(), services.end(), [&](const auto &a, const auto &b) { return collator.compare(a->name(), b->name()) < 0; });
    QVariantList result;
    for (const auto &s : services)
        result << QVariantMap{{"name", s->name()}, {"description", s->genericName()}, {"icon", s->icon()},
                              {"url", "applications:" + s->storageId()}};
    return result;
}
QVariantMap LauncherResolver::describe(const QUrl &url) const
{
    const auto service = url.isLocalFile() ? KService::serviceByDesktopPath(url.toLocalFile())
                                           : KService::serviceByStorageId(url.path());
    return {{"url", url.toString(QUrl::FullyEncoded)},
            {"name", service ? service->name() : QFileInfo(url.path()).completeBaseName()},
            {"icon", service ? service->icon() : QStringLiteral("application-x-executable")}};
}
static QString resolveLauncher(const QUrl &url, const KService::List &services)
{
    if (!url.isValid() || url.hasQuery() || url.hasFragment()) return {};
    if (url.scheme() == "applications" && url.authority().isEmpty()) {
        for (const auto &s : services)
            if (url.path() == s->storageId()) return "applications:" + s->storageId();
    } else if (url.isLocalFile()) {
        const auto path = QFileInfo(url.toLocalFile()).canonicalFilePath();
        if (path.isEmpty()) return {};
        for (const auto &s : services)
            if (path == QFileInfo(s->entryPath()).canonicalFilePath()) return "applications:" + s->storageId();
    }
    return {};
}
QString LauncherResolver::launcher(const QUrl &url) const
{
    return resolveLauncher(url, KApplicationTrader::query([](const KService::Ptr &s) { return s->isApplication(); }));
}
QVariantMap LauncherResolver::classify(const QList<QUrl> &urls) const
{
    if (urls.isEmpty() || urls.size() > 128) return {};
    const auto services = KApplicationTrader::query([](const KService::Ptr &s) { return s->isApplication(); });
    QStringList applications;
    bool documents = false;
    bool directoriesOnly = true;
    for (const auto &url : urls) {
        if (url.isLocalFile() && QFileInfo(url.toLocalFile()).isDir()) {
            documents = true;
            continue;
        }
        directoriesOnly = false;
        const auto id = resolveLauncher(url, services);
        if (!id.isEmpty()) {
            if (!applications.contains(id)) applications << id;
        } else {
            if (!url.isValid() || url.isRelative() || url.scheme() == "applications"
                || url.path().endsWith(".desktop", Qt::CaseInsensitive)
                || !(url.isLocalFile() || url.scheme() == "https" || url.scheme() == "http" || url.scheme() == "smb" || url.scheme() == "sftp")) return {};
            documents = true;
        }
    }
    // Mixed documents/launchers have no unambiguous action.
    if (documents && !applications.isEmpty()) return {};
    return {{"kind", documents ? "documents" : "applications"}, {"launchers", applications}, {"directoriesOnly", directoriesOnly}};
}
QStringList LauncherResolver::insert(const QStringList &existing, const QStringList &added, const QString &before) const
{
    const auto services = KApplicationTrader::query([](const KService::Ptr &s) { return s->isApplication(); });
    QStringList result = existing;
    QStringList fresh;
    for (const auto &url : added) {
        const auto canonical = resolveLauncher(QUrl(url), services);
        if (canonical.isEmpty() || fresh.contains(canonical)) continue;
        const bool present = std::any_of(existing.cbegin(), existing.cend(), [&](const auto &item) {
            return item == canonical || resolveLauncher(QUrl(item), services) == canonical;
        });
        if (!present) fresh << canonical;
    }
    int position = result.size();
    const auto anchor = resolveLauncher(QUrl(before), services);
    if (!anchor.isEmpty()) {
        for (int i = 0; i < result.size(); ++i)
            if (result[i] == anchor || resolveLauncher(QUrl(result[i]), services) == anchor) { position = i; break; }
    }
    for (const auto &url : fresh) result.insert(position++, url);
    return result;
}
