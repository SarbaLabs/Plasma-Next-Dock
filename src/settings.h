// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once
#include <QObject>
#include <QSettings>
#include <QVariantMap>
class DockSettings : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantMap values READ values NOTIFY changed)
    Q_PROPERTY(QString error READ error NOTIFY errorChanged)
    Q_PROPERTY(bool loginAvailable READ loginAvailable CONSTANT)
public:
    explicit DockSettings(const QString &file, bool persistent = true, QObject *parent = nullptr,
                          const QString &loginTemplate = {});
    bool loginAvailable() const { return m_persistent && !m_loginTemplate.isEmpty(); }
    Q_INVOKABLE bool startsAtLogin() const;
    Q_INVOKABLE bool setStartAtLogin(bool enabled);
    QVariantMap values() const { return m_values; }
    QString error() const { return m_error; }
    static QVariantMap defaults();
    static QVariantMap normalized(const QVariantMap &input);
    Q_INVOKABLE bool apply(const QVariantMap &changes);
    Q_INVOKABLE bool saveLaunchers(const QStringList &urls);
    void overrideSession(const QVariantMap &changes);
Q_SIGNALS:
    void changed();
    void errorChanged();
    void configureRequested();
public Q_SLOTS:
    void configure() { Q_EMIT configureRequested(); }
private:
    QSettings m_store;
    bool m_persistent;
    QString m_loginTemplate;
    QString m_loginEntry;
    QVariantMap m_values;
    QString m_error;
};
