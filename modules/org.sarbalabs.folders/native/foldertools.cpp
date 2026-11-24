// SPDX-License-Identifier: GPL-2.0-or-later
#include <QQmlExtensionPlugin>
#include <qqml.h>
#include <QFileSystemWatcher>
#include <QDir>
#include <QFileDialog>
#include <KDesktopFile>
#include <KFileItem>
#include <KIconDialog>
#include <KIO/CopyJob>
#include <KIO/OpenUrlJob>
#include <KIO/JobUiDelegateFactory>

class FolderTools : public QObject
{
    Q_OBJECT
    QFileSystemWatcher watcher;
public:
    FolderTools()
    {
        connect(&watcher, &QFileSystemWatcher::directoryChanged, this, &FolderTools::metadataChanged);
        connect(&watcher, &QFileSystemWatcher::fileChanged, this, &FolderTools::metadataChanged);
    }
    Q_INVOKABLE QString directory(const QUrl &url) const
    {
        if (!url.isLocalFile()) return {};
        const QFileInfo info(url.toLocalFile());
        return info.isDir() ? QUrl::fromLocalFile(QDir::cleanPath(info.absoluteFilePath())).toString(QUrl::FullyEncoded) : QString();
    }
    Q_INVOKABLE QVariantMap describe(const QUrl &url) const
    {
        const QString path = url.toLocalFile();
        const QFileInfo info(path);
        QString icon;
        const QString desktop = QDir(path).filePath(".directory");
        if (QFileInfo::exists(desktop)) {
            icon = KDesktopFile(desktop).readIcon();
            if (!icon.isEmpty() && QDir::isRelativePath(icon)) {
                const QString relativeFile = QDir(path).absoluteFilePath(icon);
                if (QFileInfo(relativeFile).isFile()) icon = relativeFile;
            }
        }
        if (icon.isEmpty() && info.isDir()) icon = KFileItem(url).iconName();
        return {{"name", info.fileName().isEmpty() ? path : info.fileName()},
                {"icon", icon.isEmpty() ? QStringLiteral("folder") : icon},
                {"path", path}, {"available", info.isDir()}};
    }
    // Watch metadata and its directory so atomic replacements and newly created
    // .directory files also refresh the displayed icon.
    Q_INVOKABLE void watch(const QList<QUrl> &urls)
    {
        QSet<QString> wanted;
        for (const auto &url : urls) {
            const QString path = url.toLocalFile();
            if (!url.isLocalFile() || path.isEmpty()) continue;
            if (!QFileInfo(path).isDir()) {
                // Keep disconnected or renamed shortcuts. Watch the nearest
                // existing parent to pick up a re-created directory.
                QString parent = QFileInfo(path).absolutePath();
                while (!QFileInfo(parent).isDir()) parent = QFileInfo(parent).absolutePath();
                wanted.insert(parent);
                continue;
            }
            wanted.insert(path);
            const QString desktop = QDir(path).filePath(".directory");
            if (QFileInfo::exists(desktop)) wanted.insert(desktop);
        }
        const auto paths = watcher.directories() + watcher.files();
        for (const auto &path : paths)
            if (!wanted.remove(path)) watcher.removePath(path);
        if (!wanted.isEmpty()) watcher.addPaths(wanted.values());
    }
    Q_INVOKABLE void open(const QUrl &url)
    {
        if (directory(url).isEmpty()) return;
        auto *job = new KIO::OpenUrlJob(url, QStringLiteral("inode/directory"));
        job->setUiDelegate(KIO::createDefaultJobUiDelegate(KJobUiDelegate::AutoHandlingEnabled, nullptr));
        job->start();
    }
    Q_INVOKABLE void copy(const QList<QUrl> &urls, const QUrl &destination)
    {
        if (urls.isEmpty() || directory(destination).isEmpty()) return;
        auto *job = KIO::copy(urls, destination);
        job->setUiDelegate(KIO::createDefaultJobUiDelegate(KJobUiDelegate::AutoHandlingEnabled, nullptr));
    }
    Q_INVOKABLE void chooseFolder()
    {
        auto *dialog = new QFileDialog;
        dialog->setFileMode(QFileDialog::Directory);
        dialog->setOption(QFileDialog::ShowDirsOnly);
        dialog->setAttribute(Qt::WA_DeleteOnClose);
        connect(this, &QObject::destroyed, dialog, &QObject::deleteLater);
        connect(dialog, &QFileDialog::urlSelected, this, &FolderTools::folderChosen);
        dialog->open();
    }
    Q_INVOKABLE void chooseIcon(const QString &id, const QString &current)
    {
        auto *dialog = new KIconDialog;
        dialog->setAttribute(Qt::WA_DeleteOnClose);
        dialog->setup(KIconLoader::Desktop, KIconLoader::Any);
        dialog->setSelectedIcon(current);
        connect(this, &QObject::destroyed, dialog, &QObject::deleteLater);
        connect(dialog, &KIconDialog::newIconName, this, [this, id](const QString &name) {
            if (!name.isEmpty()) Q_EMIT iconChosen(id, name);
        });
        dialog->showDialog();
    }
Q_SIGNALS:
    void metadataChanged();
    void folderChosen(const QUrl &url);
    void iconChosen(const QString &id, const QString &name);
};

class FolderPlugin : public QQmlExtensionPlugin
{
    Q_OBJECT
    Q_PLUGIN_METADATA(IID QQmlExtensionInterface_iid)
public:
    void registerTypes(const char *uri) override { qmlRegisterType<FolderTools>(uri, 1, 0, "FolderTools"); }
};

#include "foldertools.moc"
