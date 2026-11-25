// SPDX-License-Identifier: GPL-2.0-or-later
#include <QQmlExtensionPlugin>
#include <qqml.h>
#include <KCoreDirLister>
#include <KIO/DeleteOrTrashJob>
#include <KIO/JobUiDelegateFactory>
#include <KIO/OpenUrlJob>

static const QUrl trashUrl(QStringLiteral("trash:/"));

class TrashTools : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool full READ full NOTIFY fullChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
public:
    TrashTools()
    {
        // Follow KIO's aggregate trash, including hidden files and other volumes.
        m_lister.setShowHiddenFiles(true);
        connect(&m_lister, &KCoreDirLister::completed, this, &TrashTools::updateState);
        connect(&m_lister, &KCoreDirLister::itemsAdded, this, &TrashTools::updateState);
        connect(&m_lister, &KCoreDirLister::itemsDeleted, this, &TrashTools::updateState);
        connect(&m_lister, &KCoreDirLister::clear, this, &TrashTools::updateState);
        m_lister.openUrl(trashUrl);
    }
    bool full() const { return m_full; }
    bool busy() const { return m_busy; }

    Q_INVOKABLE void open()
    {
        auto *job = new KIO::OpenUrlJob(trashUrl, QStringLiteral("inode/directory"));
        job->setUiDelegate(KIO::createDefaultJobUiDelegate(KJobUiDelegate::AutoHandlingEnabled, nullptr));
        job->start();
    }
    Q_INVOKABLE void moveToTrash(const QList<QUrl> &urls)
    {
        if (urls.isEmpty()) return;
        for (const auto &url : urls)
            if (!url.isLocalFile() || !url.host().isEmpty() || url.path().isEmpty()) return;
        start(urls, KIO::AskUserActionInterface::Trash);
    }
    Q_INVOKABLE void empty()
    {
        if (m_full) start({}, KIO::AskUserActionInterface::EmptyTrash);
    }
Q_SIGNALS:
    void fullChanged();
    void busyChanged();
private:
    void updateState()
    {
        const bool full = !m_lister.items().isEmpty();
        if (full == m_full) return;
        m_full = full;
        Q_EMIT fullChanged();
    }
    void start(const QList<QUrl> &urls, KIO::AskUserActionInterface::DeletionType operation)
    {
        if (m_busy) return;
        m_busy = true;
        Q_EMIT busyChanged();
        // KIO owns confirmation, undo for trashing, progress and error dialogs.
        // The job can finish even if the user disables this dock module.
        auto *job = new KIO::DeleteOrTrashJob(urls, operation, KIO::AskUserActionInterface::DefaultConfirmation, nullptr);
        job->setUiDelegate(KIO::createDefaultJobUiDelegate(KJobUiDelegate::AutoHandlingEnabled, nullptr));
        connect(job, &KJob::result, this, [this] {
            m_busy = false;
            Q_EMIT busyChanged();
        });
        job->start();
    }
    KCoreDirLister m_lister;
    bool m_full = false;
    bool m_busy = false;
};

class TrashPlugin : public QQmlExtensionPlugin
{
    Q_OBJECT
    Q_PLUGIN_METADATA(IID QQmlExtensionInterface_iid)
public:
    void registerTypes(const char *uri) override { qmlRegisterType<TrashTools>(uri, 1, 0, "TrashTools"); }
};
#include "trashtools.moc"
