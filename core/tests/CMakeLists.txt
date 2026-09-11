find_package(Qt6 REQUIRED COMPONENTS Test)
find_program(BASH_EXECUTABLE bash REQUIRED)

# These are black-box checks for the shell-owned configuration writers.  They
# exercise their generated output and validation behavior; source layout is
# intentionally not part of the CTest suite.
add_test(
    NAME niri_cursor_config_tests
    COMMAND ${BASH_EXECUTABLE}
        ${CLAVIS_SOURCE_ROOT}/tests/test_niri_cursor_config.sh
)

add_test(
    NAME manage_niri_effects_tests
    COMMAND ${BASH_EXECUTABLE}
        ${CLAVIS_SOURCE_ROOT}/tests/test_manage_niri_effects.sh
)

add_test(
    NAME matugen_registry_tests
    COMMAND ${BASH_EXECUTABLE}
        ${CLAVIS_SOURCE_ROOT}/tests/test_matugen_registry.sh
)
set_tests_properties(matugen_registry_tests PROPERTIES SKIP_RETURN_CODE 77)

add_test(
    NAME qml_unit_tests
    COMMAND Qt6::qmltestrunner -input ${CLAVIS_SOURCE_ROOT}/tests/qml
)
set_tests_properties(qml_unit_tests PROPERTIES
    ENVIRONMENT "QT_QPA_PLATFORM=offscreen;QT_QPA_PLATFORMTHEME=;QML_IMPORT_PATH=${CLAVIS_QML_BUILD_DIR}"
)

qt_add_executable(niri_workspace_deriver_tests
    niri_workspace_deriver_test.cpp
)

target_link_libraries(niri_workspace_deriver_tests PRIVATE
    ClavisNiriCore
    Qt6::Core
    Qt6::Test
)

add_test(NAME niri_workspace_deriver_tests COMMAND niri_workspace_deriver_tests)

qt_add_executable(audio_visual_analyzer_tests
    audio_visual_analyzer_test.cpp
)

target_link_libraries(audio_visual_analyzer_tests PRIVATE
    ClavisCavaCore
    Qt6::Core
    Qt6::Test
)

add_test(NAME audio_visual_analyzer_tests COMMAND audio_visual_analyzer_tests)

qt_add_executable(lyrics_tests
    lyrics_test.cpp
)

target_link_libraries(lyrics_tests PRIVATE
    ClavisLyrics
    Qt6::Core
    Qt6::Network
    Qt6::Qml
    Qt6::Test
)

target_include_directories(lyrics_tests PRIVATE
    ${CLAVIS_SOURCE_ROOT}/core/plugin/lyrics/src
)

add_test(NAME lyrics_tests COMMAND lyrics_tests)

qt_add_executable(clavis_paths_tests
    clavis_paths_test.cpp
)

target_link_libraries(clavis_paths_tests PRIVATE
    ClavisRuntimeCore
    Qt6::Core
    Qt6::Test
)

add_test(NAME clavis_paths_tests COMMAND clavis_paths_tests)

qt_add_executable(wallpaper_analyzer_tests
    wallpaper_analyzer_test.cpp
)

target_link_libraries(wallpaper_analyzer_tests PRIVATE
    ClavisDesktopCardsCore
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Test
)

target_include_directories(wallpaper_analyzer_tests PRIVATE
    ${CLAVIS_SOURCE_ROOT}/core/plugin/desktopcards/src
)

add_test(NAME wallpaper_analyzer_tests COMMAND wallpaper_analyzer_tests)

qt_add_executable(weather_climate_normals_tests
    weather_climate_normals_test.cpp
)

target_link_libraries(weather_climate_normals_tests PRIVATE
    ClavisWeatherCore
    Qt6::Core
    Qt6::Network
    Qt6::Test
)

target_include_directories(weather_climate_normals_tests PRIVATE
    ${CLAVIS_SOURCE_ROOT}/core/src
)

add_test(NAME weather_climate_normals_tests COMMAND weather_climate_normals_tests)

qt_add_executable(i18n_manager_tests
    i18n_manager_test.cpp
)
target_link_libraries(i18n_manager_tests PRIVATE
    ClavisI18n
    Qt6::Core
    Qt6::Test
)
add_test(NAME i18n_manager_tests COMMAND i18n_manager_tests)

find_package(Python3 REQUIRED COMPONENTS Interpreter)
add_test(NAME niri_config_contracts COMMAND ${Python3_EXECUTABLE} ${CLAVIS_SOURCE_ROOT}/tests/test_niri_config.py)

qt_add_executable(device_state_tests device_state_test.cpp)
target_link_libraries(device_state_tests PRIVATE ClavisRuntimeCore Qt6::Core Qt6::Test)
add_test(NAME device_state_tests COMMAND device_state_tests)

qt_add_executable(gamma_curve_tests gamma_curve_test.cpp
    ../plugin/gamma/src/gamma_curve.cpp)
target_include_directories(gamma_curve_tests PRIVATE ../plugin/gamma/src)
target_link_libraries(gamma_curve_tests PRIVATE Qt6::Core Qt6::Test)
add_test(NAME gamma_curve_tests COMMAND gamma_curve_tests)
add_test(NAME display_preview_contracts COMMAND ${Python3_EXECUTABLE} ${CLAVIS_SOURCE_ROOT}/tests/test_display_preview.py)
qt_add_executable(niri_ipc_async_tests niri_ipc_async_test.cpp)
target_link_libraries(niri_ipc_async_tests PRIVATE ClavisNiriCore Qt6::Core Qt6::Network Qt6::Test)
add_test(NAME niri_ipc_async_tests COMMAND niri_ipc_async_tests)
