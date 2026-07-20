qt_add_library(ClavisWeatherMap SHARED)

set_target_properties(ClavisWeatherMap PROPERTIES
    LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/Clavis/WeatherMap
)

qt_add_qml_module(ClavisWeatherMap
    URI Clavis.WeatherMap
    VERSION 1.0
    SOURCES
        src/weather_map_plugin.h
        src/weather_map_plugin.cpp
    OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/Clavis/WeatherMap
)

target_include_directories(ClavisWeatherMap PUBLIC src)

target_link_libraries(ClavisWeatherMap PRIVATE
    ClavisWeatherMapCore
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Network
)
