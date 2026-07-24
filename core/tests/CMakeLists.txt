find_package(Qt6 REQUIRED COMPONENTS Test)

qt_add_executable(clavis_core_tests
    recording_core_test.cpp
)

target_link_libraries(clavis_core_tests PRIVATE
    ClavisRecordingCore
    ClavisNiriCore
    Qt6::Core
    Qt6::Test
)

add_test(NAME clavis_core_tests COMMAND clavis_core_tests)

qt_add_executable(audio_visual_analyzer_tests
    audio_visual_analyzer_test.cpp
)

target_link_libraries(audio_visual_analyzer_tests PRIVATE
    ClavisAudioCore
    Qt6::Core
    Qt6::Test
)

add_test(NAME audio_visual_analyzer_tests COMMAND audio_visual_analyzer_tests)

qt_add_executable(sysmon_core_tests
    sysmon_core_test.cpp
)

target_link_libraries(sysmon_core_tests PRIVATE
    ClavisSysmonCore
    Qt6::Core
    Qt6::Test
)

add_test(NAME sysmon_core_tests COMMAND sysmon_core_tests)

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

target_compile_features(m3shapes_tests PRIVATE cxx_std_20)
target_compile_definitions(m3shapes_tests PRIVATE
    M3SHAPES_IMPORT_PATH="$<SHELL_PATH:${CMAKE_BINARY_DIR}>"
)
add_dependencies(m3shapes_tests M3Shapes)

add_test(NAME m3shapes_tests COMMAND m3shapes_tests)
set_tests_properties(m3shapes_tests PROPERTIES
    ENVIRONMENT "QT_QPA_PLATFORM=offscreen"
)

foreach(tool_target IN ITEMS fake_gsr fake_ffmpeg fake_ffprobe fake_pactl)
    qt_add_executable(${tool_target}
        fake_recording_tool.cpp
    )
    target_link_libraries(${tool_target} PRIVATE Qt6::Core)
    set_target_properties(${tool_target} PROPERTIES
        RUNTIME_OUTPUT_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/fake-bin
    )
endforeach()

set_target_properties(fake_gsr PROPERTIES OUTPUT_NAME gpu-screen-recorder)
set_target_properties(fake_ffmpeg PROPERTIES OUTPUT_NAME ffmpeg)
set_target_properties(fake_ffprobe PROPERTIES OUTPUT_NAME ffprobe)
set_target_properties(fake_pactl PROPERTIES OUTPUT_NAME pactl)

qt_add_executable(key_integration_tests
    key_integration_test.cpp
)

target_link_libraries(key_integration_tests PRIVATE
    Qt6::Core
    Qt6::Test
)

target_compile_definitions(key_integration_tests PRIVATE
    KEY_EXECUTABLE="$<TARGET_FILE:key>"
    KEY_FAKE_BIN="${CMAKE_CURRENT_BINARY_DIR}/fake-bin"
)

add_dependencies(key_integration_tests
    key
    fake_gsr
    fake_ffmpeg
    fake_ffprobe
    fake_pactl
)

add_test(NAME key_integration_tests COMMAND key_integration_tests)

qt_add_executable(key_sysmon_integration_tests
    key_sysmon_integration_test.cpp
)

target_link_libraries(key_sysmon_integration_tests PRIVATE
    Qt6::Core
    Qt6::Test
)

target_compile_definitions(key_sysmon_integration_tests PRIVATE
    KEY_EXECUTABLE="$<TARGET_FILE:key>"
)

add_dependencies(key_sysmon_integration_tests key)
add_test(NAME key_sysmon_integration_tests COMMAND key_sysmon_integration_tests)
