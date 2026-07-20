#include "weather_list_model.h"

WeatherListModel::WeatherListModel(QObject *parent) : QAbstractListModel(parent) {
    const QList<QByteArray> names = {
        "time", "date", "weatherCode", "weatherText", "iconName", "isDaylight",
        "temperatureC", "temperatureMaxC", "temperatureMinC", "sourceFeelsLikeC", "feelsLikeC",
        "apparentTemperatureMaxC", "apparentTemperatureMinC",
        "precipitationMm", "precipitationIntensityMmH", "precipitationProbability",
        "rainMm", "snowCm", "windSpeedMs", "windDirection", "windGustsMs",
        "uvIndex", "uvIndexMax", "relativeHumidity", "relativeHumidityMean",
        "relativeHumidityMax", "relativeHumidityMin", "dewPointC", "dewPointMeanC",
        "dewPointMaxC", "dewPointMinC", "pressureHpa", "pressureMeanHpa",
        "pressureMaxHpa", "pressureMinHpa", "cloudCover", "cloudCoverMean",
        "cloudCoverMax", "cloudCoverMin", "visibilityM", "visibilityMeanM",
        "visibilityMaxM", "visibilityMinM", "sunshineDurationS", "sunrise",
        "sunset", "dawn", "dusk", "moonrise", "moonset", "moonPhaseAngle",
        "day", "night", "airQuality", "minuteInterval"
    };
    for (int i = 0; i < names.size(); ++i) {
        m_roles[Qt::UserRole + 1 + i] = names[i];
    }
}

int WeatherListModel::rowCount(const QModelIndex &parent) const {
    if (parent.isValid()) return 0;
    return m_items.size();
}

QVariant WeatherListModel::data(const QModelIndex &index, int role) const {
    if (!index.isValid() || index.row() < 0 || index.row() >= m_items.size()) return {};
    if (role == Qt::DisplayRole) return m_items[index.row()];
    const auto name = m_roles.value(role);
    if (name.isEmpty()) return {};
    return m_items[index.row()].value(QString::fromUtf8(name));
}

QHash<int, QByteArray> WeatherListModel::roleNames() const {
    return m_roles;
}

QVariantMap WeatherListModel::get(int index) const {
    if (index < 0 || index >= m_items.size()) return {};
    return m_items[index];
}

int WeatherListModel::count() const {
    return m_items.size();
}

void WeatherListModel::setItems(const QList<QVariantMap> &items) {
    beginResetModel();
    m_items = items;
    endResetModel();
}
