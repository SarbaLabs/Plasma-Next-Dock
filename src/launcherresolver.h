// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once
#include <QObject>
#include <QUrl>
#include <QVariantList>

// Installed desktop-entry identities only; never execute or import dropped files.
class LauncherResolver : public QObject
{
    Q_OBJECT
public:
    using QObject::QObject;
    Q_INVOKABLE QVariantList applications() const;
    Q_INVOKABLE QString launcher(const QUrl &url) const;
    Q_INVOKABLE QVariantMap classify(const QList<QUrl> &urls) const;
    Q_INVOKABLE QStringList insert(const QStringList &existing, const QStringList &added, const QString &before) const;
};
