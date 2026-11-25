// SPDX-License-Identifier: GPL-2.0-or-later
#include "modules/modulemanager.h"
#include <QApplication>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QTemporaryDir>
#include <QTest>

class UsbModuleTest : public QObject
{
    Q_OBJECT
private Q_SLOTS:
    void hotplug()
    {
        QTemporaryDir home;
        QVERIFY(home.isValid());
        qputenv("XDG_CONFIG_HOME", home.filePath("config").toUtf8());
        qputenv("XDG_DATA_HOME", home.filePath("data").toUtf8());
        qputenv("XDG_CACHE_HOME", home.filePath("cache").toUtf8());
        const QString module = QStringLiteral("org.sarbalabs.usb");
        const QString first = QStringLiteral("/org/kde/solid/fakehw/stickA1");
        const QString second = QStringLiteral("/org/kde/solid/fakehw/stickB1");
        ModuleManager manager({{module, {{}, QUrl::fromLocalFile(QStringLiteral(USB_PACKAGE) + "/Main.qml")}}});
        manager.configure({module}, {});
        QVERIFY(manager.loaded(module));
        QTRY_COMPARE(manager.entries().size(), 2);
        QVERIFY(manager.trigger(module, first, "mount"));
        const auto canUnmount = [&] {
            for (const auto &value : manager.entries()) {
                const auto entry = value.toMap();
                if (entry["id"] != first) continue;
                for (const auto &action : entry["actions"].toList())
                    if (action.toMap()["id"] == "unmount") return true;
            }
            return false;
        };
        QTRY_VERIFY(canUnmount());
        QVERIFY(manager.trigger(module, first, "unmount"));
        QTRY_VERIFY(!canUnmount());
        QVERIFY(!manager.trigger(module, second, "remove"));
        // Only Solid's fake backend provides this object on our private bus.
        auto change = [](const QString &method, const QString &id) {
            auto bus = QDBusConnection::sessionBus();
            auto message = QDBusMessage::createMethodCall(bus.baseService(), "/org/kde/solid/fakehw", {}, method);
            message << id;
            return bus.call(message).type() == QDBusMessage::ReplyMessage;
        };
        QVERIFY(change("unplug", first));
        QTRY_COMPARE(manager.entries().size(), 1);
        QVERIFY(!manager.activate(module, first));
        QVERIFY(change("unplug", second));
        QTRY_VERIFY(manager.entries().isEmpty());
        QVERIFY(change("plug", second));
        QTRY_COMPARE(manager.entries().size(), 1);
        QCOMPARE(manager.entries().first().toMap()["id"].toString(), second);
    }
};
QTEST_MAIN(UsbModuleTest)
#include "usbmoduletest.moc"
