// SPDX-License-Identifier: GPL-2.0-or-later
#include <KFilePlacesModel>
#include <KIO/JobUiDelegateFactory>
#include <KIO/OpenUrlJob>
#include <Solid/StorageAccess>
#include <Solid/StorageDrive>
#include <Solid/StorageVolume>
#include <QDBusConnection>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QMessageBox>
#include <QQmlExtensionPlugin>
#include <qqml.h>
#include <QTimer>
#include <memory>

namespace {
const QString service = QStringLiteral("org.freedesktop.UDisks2");
const QString driveInterface = service + QStringLiteral(".Drive");

Solid::Device usbDrive(const Solid::Device &volume)
{
    const auto *filesystem = volume.as<Solid::StorageVolume>();
    if (!filesystem || filesystem->isIgnored()
        || !volume.is<Solid::StorageAccess>()) return Solid::Device();
    if (filesystem->usage() != Solid::StorageVolume::FileSystem && filesystem->usage() != Solid::StorageVolume::Encrypted)
        return Solid::Device();
    for (auto device = volume; device.isValid(); device = device.parent()) {
        if (const auto *drive = device.as<Solid::StorageDrive>())
            return drive->bus() == Solid::StorageDrive::Usb ? device : Solid::Device();
    }
    return Solid::Device();
}

void showError(const QString &message)
{
    auto *dialog = new QMessageBox(QMessageBox::Warning, QStringLiteral("Plasma Next Dock"), message, QMessageBox::Ok);
    dialog->setAttribute(Qt::WA_DeleteOnClose);
    dialog->show();
}

void openVolume(const QUrl &url)
{
    if (!url.isLocalFile() || url.toLocalFile().isEmpty()) return;
    auto *job = new KIO::OpenUrlJob(url, QStringLiteral("inode/directory"));
    job->setUiDelegate(KIO::createDefaultJobUiDelegate(KJobUiDelegate::AutoHandlingEnabled, nullptr));
    job->start();
}

// One drive can expose several volumes. The request and capability watchers
// belong to this attachment, so removing it also cancels stale callbacks.
struct DriveState : QObject
{
    QString removal;
    bool removing = false;
};

class UsbStorage : public QObject
{
    Q_OBJECT
public:
    UsbStorage()
    {
        refreshTimer.setSingleShot(true);
        connect(&refreshTimer, &QTimer::timeout, this, &UsbStorage::refresh);
        const auto schedule = [this] { refreshTimer.start(0); };
        connect(&places, &KFilePlacesModel::rowsInserted, this, schedule);
        connect(&places, &KFilePlacesModel::rowsRemoved, this, schedule);
        connect(&places, &KFilePlacesModel::modelReset, this, schedule);
        connect(&places, &KFilePlacesModel::layoutChanged, this, schedule);
        connect(&places, &KFilePlacesModel::dataChanged, this, schedule);
        connect(&places, &KFilePlacesModel::errorMessage, this, &showError);
        connect(&places, &KFilePlacesModel::setupDone, this, [this](const QModelIndex &idx, bool success) {
            if (openAfterMount.removeAll(idx) && success) openVolume(places.url(idx));
            refresh();
        });
        refresh();
    }

    QVariantList volumes;
    void run(const QString &id, const QString &action)
    {
        // Re-resolve both state and permissions when a menu outlives its volume.
        refresh();
        const auto idx = indexes.value(id);
        if (!idx.isValid()) return;
        const auto drive = usbDrive(places.deviceForIndex(idx));
        auto *state = drives.value(drive.udi());
        if (!state || state->removing) return;
        const auto access = places.deviceAccessibility(idx);
        if (access == KFilePlacesModel::SetupNeeded && (action == "mount" || action == "open")) {
            if (action == "open") openAfterMount.append(idx);
            places.requestSetup(idx);
        } else if (access == KFilePlacesModel::Accessible && action == "open") {
            openVolume(places.url(idx));
        } else if (access == KFilePlacesModel::Accessible && action == "unmount" && places.isTeardownAllowed(idx)) {
            places.requestTeardown(idx);
        } else if (action == "remove" && !state->removal.isEmpty() && !inUse.contains(drive.udi())) {
            state->removing = true;
            auto msg = QDBusMessage::createMethodCall(service, drive.udi(), driveInterface, state->removal);
            msg << QVariantMap();
            msg.setInteractiveAuthorizationAllowed(true);
            auto *watch = new QDBusPendingCallWatcher(QDBusConnection::systemBus().asyncCall(msg), state);
            connect(watch, &QDBusPendingCallWatcher::finished, this, [this, watch, state] {
                QDBusPendingReply<> reply = *watch;
                state->removing = false;
                watch->deleteLater();
                if (reply.isError()) showError(reply.error().message().toHtmlEscaped());
                refresh();
            });
        }
        refresh();
    }
Q_SIGNALS:
    void changed();
private:
    DriveState *observeDrive(const QString &udi)
    {
        if (auto *existing = drives.value(udi)) return existing;
        auto *state = new DriveState;
        state->setParent(this);
        drives.insert(udi, state);
        // Solid handles mounting through Places. UDisks additionally advertises
        // whether this physical drive supports power-off or media ejection.
        if (!udi.startsWith("/org/freedesktop/UDisks2/drives/")) return state;
        auto msg = QDBusMessage::createMethodCall(service, udi, QStringLiteral("org.freedesktop.DBus.Properties"), QStringLiteral("GetAll"));
        msg << driveInterface;
        auto *watch = new QDBusPendingCallWatcher(QDBusConnection::systemBus().asyncCall(msg), state);
        connect(watch, &QDBusPendingCallWatcher::finished, this, [this, watch, state] {
            QDBusPendingReply<QVariantMap> reply = *watch;
            watch->deleteLater();
            if (reply.isError()) return;
            const auto props = reply.value();
            // UDisks checks the drive and its siblings for users before power-off.
            if (props.value("CanPowerOff").toBool())
                state->removal = QStringLiteral("PowerOff");
            else if (props.value("Ejectable").toBool())
                state->removal = QStringLiteral("Eject");
            refresh();
        });
        return state;
    }

    void refresh()
    {
        indexes.clear();
        inUse.clear();
        QSet<QString> present;
        QVariantList rows;
        for (int i = 0; i < places.rowCount(); ++i) {
            const auto idx = places.index(i, 0);
            const auto volume = places.deviceForIndex(idx);
            if (!volume.isValid()) continue;
            const auto drive = usbDrive(volume);
            if (!drive.isValid()) continue;
            indexes.insert(volume.udi(), idx);
            present.insert(drive.udi());
            auto *state = observeDrive(drive.udi());
            const auto access = places.deviceAccessibility(idx);
            const bool mounted = access == KFilePlacesModel::Accessible;
            if (access != KFilePlacesModel::SetupNeeded || drive.as<Solid::StorageDrive>()->isInUse())
                inUse.insert(drive.udi());
            QString icon = idx.data(KFilePlacesModel::IconNameRole).toString();
            if (icon.isEmpty()) icon = QStringLiteral("drive-removable-media-usb");
            QString name = places.text(idx);
            if (name.isEmpty()) name = volume.as<Solid::StorageVolume>()->label();
            if (name.isEmpty()) name = volume.udi().section('/', -1);
            rows.append(QVariantMap{{"id", volume.udi()}, {"drive", drive.udi()}, {"icon", icon}, {"name", name},
                                    {"mounted", mounted}, {"canUnmount", mounted && places.isTeardownAllowed(idx)},
                                    {"busy", state->removing || (!mounted && access != KFilePlacesModel::SetupNeeded)},
                                    {"removal", state->removal}});
        }
        for (auto it = drives.begin(); it != drives.end();) {
            if (present.contains(it.key())) { ++it; continue; }
            delete it.value();
            it = drives.erase(it);
        }
        openAfterMount.removeAll(QPersistentModelIndex());
        for (auto &row : rows) {
            auto data = row.toMap();
            data.insert("canRemove", !inUse.contains(data.take("drive").toString()));
            row = data;
        }
        if (rows == volumes) return;
        volumes = rows;
        Q_EMIT changed();
    }

    KFilePlacesModel places;
    QTimer refreshTimer;
    QHash<QString, QPersistentModelIndex> indexes;
    QList<QPersistentModelIndex> openAfterMount;
    QHash<QString, DriveState *> drives;
    QSet<QString> inUse;
};
}

// Share pending operations between docks; release the observer when the last
// USB module goes away, while keeping each QML engine's object ownership local.
class UsbTools : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantList volumes READ volumes NOTIFY changed)
public:
    UsbTools()
    {
        static std::weak_ptr<UsbStorage> shared;
        storage = shared.lock();
        if (!storage) shared = storage = std::make_shared<UsbStorage>();
        connect(storage.get(), &UsbStorage::changed, this, &UsbTools::changed);
    }
    QVariantList volumes() const { return storage->volumes; }
    Q_INVOKABLE void run(const QString &id, const QString &action) { storage->run(id, action); }
Q_SIGNALS:
    void changed();
private:
    std::shared_ptr<UsbStorage> storage;
};

class UsbPlugin : public QQmlExtensionPlugin
{
    Q_OBJECT
    Q_PLUGIN_METADATA(IID QQmlExtensionInterface_iid)
public:
    void registerTypes(const char *uri) override { qmlRegisterType<UsbTools>(uri, 1, 0, "UsbTools"); }
};
#include "usbtools.moc"
