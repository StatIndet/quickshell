# 纯底层可复用的架构层
qt_add_library(ClavisSysmonCore STATIC)
target_sources(ClavisSysmonCore PRIVATE
    sysmon_types.h
    sysmon_backend.h
    sysmon_backend.cpp
    sysmon_cpu.h
    sysmon_cpu.cpp
    sysmon_ram.h
    sysmon_ram.cpp
    sysmon_disk.h
    sysmon_disk.cpp
    sysmon_temp.h
    sysmon_temp.cpp
    sysmon_net.h
    sysmon_net.cpp
    sysmon_load.h
    sysmon_load.cpp
    sysmon_battery.h
    sysmon_battery.cpp
    sysmon_gpu.h
    sysmon_gpu.cpp
    sysmon_misc.h
    sysmon_misc.cpp
)

# 确保在共享库被链接时开启 -fPIC
set_target_properties(ClavisSysmonCore PROPERTIES POSITION_INDEPENDENT_CODE ON)

target_link_libraries(ClavisSysmonCore PRIVATE Qt6::Core)
target_include_directories(ClavisSysmonCore PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})

qt_add_library(ClavisWeatherCore STATIC)
target_sources(ClavisWeatherCore PRIVATE
    weather_types.h
    weather_types.cpp
    weather_calculator.h
    weather_calculator.cpp
    weather_cache.h
    weather_cache.cpp
    openmeteo_client.h
    openmeteo_client.cpp
    weather_backend.h
    weather_backend.cpp
)

set_target_properties(ClavisWeatherCore PROPERTIES POSITION_INDEPENDENT_CODE ON)

target_link_libraries(ClavisWeatherCore PRIVATE
    Qt6::Core
    Qt6::Network
)
target_include_directories(ClavisWeatherCore PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})

qt_add_library(ClavisWeatherMapCore STATIC)
target_sources(ClavisWeatherMapCore PRIVATE
    weather_map_provider.h
    weather_map_provider.cpp
)

set_target_properties(ClavisWeatherMapCore PROPERTIES POSITION_INDEPENDENT_CODE ON)

target_link_libraries(ClavisWeatherMapCore PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Network
)
target_include_directories(ClavisWeatherMapCore PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})

qt_add_library(ClavisNiriCore STATIC)
target_sources(ClavisNiriCore PRIVATE
    niri_types.h
    niri_icon_lookup.h
    niri_icon_lookup.cpp
    niri_ipc_client.h
    niri_ipc_client.cpp
    niri_workspace_model.h
    niri_workspace_model.cpp
    niri_window_model.h
    niri_window_model.cpp
    niri_output_model.h
    niri_output_model.cpp
)

set_target_properties(ClavisNiriCore PROPERTIES POSITION_INDEPENDENT_CODE ON)

target_link_libraries(ClavisNiriCore PRIVATE
    Qt6::Core
    Qt6::Network
)
target_include_directories(ClavisNiriCore PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})

qt_add_library(ClavisAudioCore STATIC)
target_sources(ClavisAudioCore PRIVATE
    audio_collector.h
    audio_collector.cpp
)

set_target_properties(ClavisAudioCore PROPERTIES POSITION_INDEPENDENT_CODE ON)

target_link_libraries(ClavisAudioCore PRIVATE
    Qt6::Core
    PkgConfig::Pipewire
)
target_include_directories(ClavisAudioCore PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})

qt_add_library(ClavisMediaCore STATIC)
target_sources(ClavisMediaCore PRIVATE
    media_palette_backend.h
    media_palette_backend.cpp
)

set_target_properties(ClavisMediaCore PROPERTIES POSITION_INDEPENDENT_CODE ON)

target_link_libraries(ClavisMediaCore PRIVATE
    Qt6::Core
    Qt6::Gui
)
target_include_directories(ClavisMediaCore PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})
