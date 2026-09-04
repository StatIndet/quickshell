# 纯底层可复用的架构层。RuntimeCore 先定义，供其他 core target 共享。
qt_add_library(ClavisRuntimeCore STATIC)
target_sources(ClavisRuntimeCore PRIVATE
    runtime/clavis_paths.h
    runtime/clavis_paths.cpp
)
set_target_properties(ClavisRuntimeCore PROPERTIES POSITION_INDEPENDENT_CODE ON)
target_link_libraries(ClavisRuntimeCore PRIVATE Qt6::Core Qt6::Network)
target_include_directories(ClavisRuntimeCore PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})

qt_add_library(ClavisWeatherMapCore STATIC)
target_sources(ClavisWeatherMapCore PRIVATE
    weather_map_provider.h
    weather_map_provider.cpp
)

set_target_properties(ClavisWeatherMapCore PROPERTIES POSITION_INDEPENDENT_CODE ON)

target_link_libraries(ClavisWeatherMapCore PRIVATE
    ClavisRuntimeCore
    Qt6::Core
    Qt6::Gui
    Qt6::Network
    Qt6Keychain::Qt6Keychain
)
target_include_directories(ClavisWeatherMapCore PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})

qt_add_library(ClavisWeatherCore STATIC)
target_sources(ClavisWeatherCore PRIVATE
    weather_types.h
    weather_types.cpp
    weather_calculator.h
    weather_calculator.cpp
    weather_cache.h
    weather_cache.cpp
    weather_climate_normals.h
    weather_climate_normals.cpp
    weather_normals_cache.h
    weather_normals_cache.cpp
    openmeteo_client.h
    openmeteo_client.cpp
    weather_backend.h
    weather_backend.cpp
)
set_target_properties(ClavisWeatherCore PROPERTIES POSITION_INDEPENDENT_CODE ON)
target_link_libraries(ClavisWeatherCore PRIVATE Qt6::Core Qt6::Network)
target_include_directories(ClavisWeatherCore PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})

qt_add_library(ClavisNiriCore STATIC)
target_sources(ClavisNiriCore PRIVATE
    niri_types.h
    niri_icon_lookup.h
    niri_icon_lookup.cpp
    niri_ipc_client.h
    niri_ipc_client.cpp
    niri_workspace_deriver.h
    niri_workspace_deriver.cpp
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

qt_add_library(ClavisCavaCore STATIC)
target_sources(ClavisCavaCore PRIVATE
    audio_collector.h
    audio_collector.cpp
    audio_level_collector.h
    audio_level_collector.cpp
    audio_visual_analyzer.h
    audio_visual_analyzer.cpp
)

set_target_properties(ClavisCavaCore PROPERTIES POSITION_INDEPENDENT_CODE ON)

target_link_libraries(ClavisCavaCore PRIVATE
    Qt6::Core
    PkgConfig::Pipewire
)
target_include_directories(ClavisCavaCore PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})

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

# Material 3 expressive shape geometry and morphing backend.  The vendored
# source is kept in its own subdirectory because it requires C++20 while the
# rest of ClavisCore intentionally remains on C++17.
add_subdirectory(m3shapes)
