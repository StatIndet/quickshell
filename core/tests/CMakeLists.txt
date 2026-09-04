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

qt_add_executable(m3shapes_tests
    m3shapes_test.cpp
)

target_link_libraries(m3shapes_tests PRIVATE
    M3ShapesCore
    M3ShapesMorph
    M3ShapesGeometry
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::Test
)

target_include_directories(m3shapes_tests PRIVATE
    ${CLAVIS_SOURCE_ROOT}/core/src
)

target_compile_features(m3shapes_tests PRIVATE cxx_std_20)
target_compile_definitions(m3shapes_tests PRIVATE
    M3SHAPES_IMPORT_PATH="$<SHELL_PATH:${CLAVIS_QML_BUILD_DIR}>"
)
add_dependencies(m3shapes_tests M3Shapes)

add_test(NAME m3shapes_tests COMMAND m3shapes_tests)
set_tests_properties(m3shapes_tests PROPERTIES
    ENVIRONMENT "QT_QPA_PLATFORM=offscreen"
)

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
