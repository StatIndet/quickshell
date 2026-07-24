qt_add_executable(key
    src/main.cpp
    src/command_result.h
    src/command_router.h
    src/command_router.cpp
    src/commands/doctor_command.h
    src/commands/doctor_command.cpp
    src/commands/audio_command.h
    src/commands/audio_command.cpp
    src/commands/record_command.h
    src/commands/record_command.cpp
    src/commands/cast_command.h
    src/commands/cast_command.cpp
    src/commands/sysmon_command.h
    src/commands/sysmon_command.cpp
    src/commands/top_command.h
    src/commands/top_command.cpp
    src/tui/top_tui.h
    src/tui/top_tui.cpp
)

set_target_properties(key PROPERTIES
    OUTPUT_NAME key
    RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin
)

target_link_libraries(key PRIVATE
    ClavisSysmonCore
    ClavisRecordingCore
    ClavisNiriCore
    Qt6::Core
    Qt6::Network
    PkgConfig::NCursesW
)

target_include_directories(key PRIVATE src)

install(TARGETS key
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
