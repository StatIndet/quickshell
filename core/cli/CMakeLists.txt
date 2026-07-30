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
    src/commands/clipboard_command.h
    src/commands/clipboard_command.cpp
    src/commands/sysmon_command.h
    src/commands/sysmon_command.cpp
    src/commands/top_command.h
    src/commands/top_command.cpp
    src/tui/top_tui.h
    src/tui/top_tui_helpers.h
    src/tui/top_tui_helpers.cpp
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

# Linux exposes Intel RAPL package energy as a root-readable sysfs counter on
# hardened kernels. btop solves the same problem with cap_dac_read_search.
# Keep this opt-out so packagers can provide an ACL/udev policy instead.
option(
    CLAVIS_INSTALL_RAPL_CAPABILITY
    "Grant the installed key executable permission to read Intel RAPL energy"
    ON
)

if(CMAKE_SYSTEM_NAME STREQUAL "Linux" AND CLAVIS_INSTALL_RAPL_CAPABILITY)
    find_program(CLAVIS_SETCAP_EXECUTABLE NAMES setcap)
    if(CLAVIS_SETCAP_EXECUTABLE)
        configure_file(
            cmake/InstallKeyCapabilities.cmake.in
            ${CMAKE_CURRENT_BINARY_DIR}/InstallKeyCapabilities.cmake
            @ONLY
        )
        install(SCRIPT
            ${CMAKE_CURRENT_BINARY_DIR}/InstallKeyCapabilities.cmake
        )
    else()
        message(WARNING
            "setcap was not found; installed key cannot read protected "
            "Intel RAPL CPU energy counters")
    endif()
endif()
