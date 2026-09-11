#pragma once
#include <QObject>
#include <QVariantList>
#include <QtQml/qqmlregistration.h>
#include <memory>
class GammaBackend : public QObject {
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(bool available READ available NOTIFY changed)
    Q_PROPERTY(QVariantList outputs READ outputs NOTIFY changed)
  public:
    explicit GammaBackend(QObject *parent = nullptr);
    ~GammaBackend() override;
    bool available() const;
    QVariantList outputs() const;
    Q_INVOKABLE bool apply(double gamma, double contrast, int temperature, double dimming);
    Q_INVOKABLE void retry();
  signals:
    void changed();
    void resumed();
  private slots:
    void prepareForSleep(bool sleeping);

  private:
    struct Private;
    std::unique_ptr<Private> d;
};
