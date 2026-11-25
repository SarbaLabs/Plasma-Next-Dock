// SPDX-License-Identifier: GPL-2.0-or-later
#include <KApplicationTrader>
#include <KIconDialog>
#include <KIO/ApplicationLauncherJob>
#include <KIO/JobUiDelegateFactory>
#include <KServiceGroup>
#include <KSycoca>
#include <QCollator>
#include <QDrag>
#include <QIcon>
#include <QMimeData>
#include <QProcess>
#include <QQmlExtensionPlugin>
#include <QQuickWindow>
#include <QUuid>
#include <QStandardPaths>
#include <qqml.h>
#include <algorithm>

class MenuTools : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool editorAvailable READ editorAvailable CONSTANT)
public:
    bool editorAvailable() const { return !QStandardPaths::findExecutable("kmenuedit").isEmpty(); }
    Q_INVOKABLE void editApplications() { QProcess::startDetached("kmenuedit", {}); }
    Q_INVOKABLE void chooseIcon(const QString &current)
    {
        auto *dialog = new KIconDialog;
        dialog->setAttribute(Qt::WA_DeleteOnClose);
        dialog->setup(KIconLoader::Desktop, KIconLoader::Any);
        dialog->setSelectedIcon(current);
        connect(this, &QObject::destroyed, dialog, &QObject::deleteLater);
        connect(dialog, &KIconDialog::newIconName, this, &MenuTools::iconChosen);
        dialog->showDialog();
    }
Q_SIGNALS:
    void iconChosen(const QString &name);
};

// Query one directory at a time. An unopened menu needs no catalog or watcher.
class Catalog : public QObject
{
    Q_OBJECT
    // Only this open menu accepts its favorite drags. Every dock accepts the
    // standard applications: URL through its usual validated launcher drop path.
    Q_PROPERTY(QString favoriteFormat MEMBER m_favoriteFormat CONSTANT)
public:
    Catalog() { connect(KSycoca::self(), &KSycoca::databaseChanged, this, &Catalog::changed, Qt::QueuedConnection); }
    Q_INVOKABLE QUrl launcherUrl(const QString &id) const
    {
        QUrl url;
        url.setScheme(QStringLiteral("applications"));
        url.setPath(id);
        return url;
    }
    Q_INVOKABLE void dragApplication(QQuickWindow *window, const QString &id, bool favorite)
    {
        const auto service = KService::serviceByStorageId(id);
        if (!window || !service || !service->isApplication()) return;
        auto *mime = new QMimeData;
        mime->setUrls({launcherUrl(service->storageId())});
        if (favorite) mime->setData(m_favoriteFormat, id.toUtf8());
        auto *drag = new QDrag(window);
        drag->setMimeData(mime);
        const auto image = QIcon::fromTheme(service->icon(), QIcon::fromTheme(QStringLiteral("application-x-executable")))
                               .pixmap(QSize(32, 32), window->devicePixelRatio());
        drag->setPixmap(image);
        drag->setHotSpot(QPoint(16, 16));
        drag->exec(Qt::CopyAction);
    }
    Q_INVOKABLE QVariantList group(const QString &path, bool alphabetical) const
    {
        const auto group = path.isEmpty() ? KServiceGroup::root() : KServiceGroup::group(path);
        QVariantList rows;
        if (!group || !group->isValid()) return rows;
        for (const auto &entry : group->entries(true, true, false)) {
            if (entry->isType(KST_KServiceGroup)) {
                const auto *g = static_cast<const KServiceGroup *>(entry.data());
                if (g->childCount() || g->showEmptyMenu())
                    rows << QVariantMap{{"group", true}, {"id", g->relPath()}, {"name", g->caption()}, {"icon", g->icon()}};
            } else if (entry->isType(KST_KService)) {
                const auto *s = static_cast<const KService *>(entry.data());
                if (s->showInCurrentDesktop()) rows << application(s);
            }
        }
        if (alphabetical) {
            QCollator comparator;
            comparator.setCaseSensitivity(Qt::CaseInsensitive);
            std::stable_sort(rows.begin(), rows.end(), [&](const QVariant &a, const QVariant &b) {
                return comparator.compare(a.toMap().value("name").toString(), b.toMap().value("name").toString()) < 0;
            });
        }
        return rows;
    }
    Q_INVOKABLE QVariantList allApplications() const
    {
        auto services = KApplicationTrader::query([](const KService::Ptr &service) {
            return service->isApplication() && !service->noDisplay() && service->showInCurrentDesktop();
        });
        QCollator collator;
        collator.setCaseSensitivity(Qt::CaseInsensitive);
        std::sort(services.begin(), services.end(), [&](const auto &a, const auto &b) {
            return collator.compare(a->name(), b->name()) < 0;
        });
        QVariantList rows;
        for (const auto &service : services) rows << application(service.data());
        return rows;
    }
    Q_INVOKABLE QVariantList favorites(const QStringList &ids) const
    {
        QVariantList rows;
        for (const auto &id : ids) {
            const auto s = KService::serviceByStorageId(id);
            if (s && !s->noDisplay() && s->showInCurrentDesktop()) rows << application(s.data());
        }
        return rows;
    }
    Q_INVOKABLE void launch(const QString &id)
    {
        const auto service = KService::serviceByStorageId(id);
        if (!service || !service->isApplication()) return;
        auto *job = new KIO::ApplicationLauncherJob(service);
        job->setUiDelegate(KIO::createDefaultJobUiDelegate(KJobUiDelegate::AutoHandlingEnabled, nullptr));
        job->start();
    }
Q_SIGNALS:
    void changed();
private:
    const QString m_favoriteFormat = QStringLiteral("application/x-pnd-favorite-") + QUuid::createUuid().toString(QUuid::WithoutBraces);
    static QVariantMap application(const KService *s)
    {
        return {{"id", s->storageId()}, {"name", s->name()}, {"icon", s->icon()},
                {"generic", s->genericName()}, {"comment", s->comment()}};
    }
};
class MenuPlugin : public QQmlExtensionPlugin
{
    Q_OBJECT
    Q_PLUGIN_METADATA(IID QQmlExtensionInterface_iid)
public:
    void registerTypes(const char *uri) override
    {
        qmlRegisterType<MenuTools>(uri, 1, 0, "MenuTools");
        qmlRegisterType<Catalog>(uri, 1, 0, "Catalog");
    }
};
#include "menutools.moc"
