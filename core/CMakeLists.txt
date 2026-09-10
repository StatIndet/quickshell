include(GNUInstallDirs)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
# globally enable MOC to parse Q_OBJECT macros
set(CMAKE_AUTOMOC ON)

set(CLAVIS_RELEASE "development" CACHE STRING "Clavis date release")
set(CLAVIS_COMMIT "unknown" CACHE STRING "Git commit embedded in the release")
set(CLAVIS_SOURCE_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/..")
get_filename_component(CLAVIS_SOURCE_ROOT "${CLAVIS_SOURCE_ROOT}" ABSOLUTE)
if(CLAVIS_COMMIT STREQUAL "unknown")
    find_package(Git QUIET)
    if(Git_FOUND)
        execute_process(
            COMMAND "${GIT_EXECUTABLE}" rev-parse HEAD
            WORKING_DIRECTORY "${CLAVIS_SOURCE_ROOT}"
            OUTPUT_VARIABLE CLAVIS_GIT_COMMIT
            OUTPUT_STRIP_TRAILING_WHITESPACE
            ERROR_QUIET
        )
        if(CLAVIS_GIT_COMMIT)
            set(CLAVIS_COMMIT "${CLAVIS_GIT_COMMIT}")
        endif()
    endif()
endif()
if(NOT CLAVIS_BUILD_TIME)
    string(TIMESTAMP CLAVIS_BUILD_TIME "%Y-%m-%dT%H:%M:%SZ" UTC)
endif()
configure_file(
    "${CMAKE_CURRENT_SOURCE_DIR}/clavis_release.h.in"
    "${CMAKE_BINARY_DIR}/generated/clavis_release.h"
    @ONLY
)

if(NOT DEFINED CLAVIS_QML_BUILD_DIR)
    set(CLAVIS_QML_BUILD_DIR "${CMAKE_BINARY_DIR}/qml")
endif()
set(QT_QML_OUTPUT_DIRECTORY "${CLAVIS_QML_BUILD_DIR}")
if(NOT DEFINED CLAVIS_QML_INSTALL_DIR)
    set(CLAVIS_QML_INSTALL_DIR "${CMAKE_INSTALL_LIBDIR}/qt6/qml")
endif()
if(NOT DEFINED CLAVIS_CONFIG_INSTALL_DIR)
    set(CLAVIS_CONFIG_INSTALL_DIR "etc/xdg/quickshell/clavis")
endif()
# Find Qt 6 basics
find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml Quick Network ShaderTools LinguistTools)
find_package(Qt6Keychain REQUIRED)
find_package(PkgConfig REQUIRED)
pkg_check_modules(Pipewire IMPORTED_TARGET libpipewire-0.3 REQUIRED)
pkg_check_modules(Cava IMPORTED_TARGET libcava QUIET)
if(NOT Cava_FOUND)
    pkg_check_modules(Cava IMPORTED_TARGET cava REQUIRED)
endif()
qt_standard_project_setup(REQUIRES 6.5)

if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
    add_compile_options(-Wall -Wextra -Wpedantic)
endif()

# Base reusable logic
add_subdirectory(src)
add_subdirectory(plugin/desktopcards)

if(BUILD_TESTING)
    add_subdirectory(tests)
endif()

# Quickshell plugins
add_subdirectory(plugin/weather)
add_subdirectory(plugin/weathermap)
add_subdirectory(plugin/niri)
add_subdirectory(plugin/cava)
add_subdirectory(plugin/media)
add_subdirectory(plugin/keyboard)
add_subdirectory(plugin/lyrics)
add_subdirectory(plugin/i18n)
add_subdirectory(plugin/runtime)

install(
    DIRECTORY "${CLAVIS_QML_BUILD_DIR}/Clavis/"
    DESTINATION "${CLAVIS_QML_INSTALL_DIR}/Clavis"
    FILES_MATCHING
        PATTERN "qmldir"
        PATTERN "*.qmltypes"
        PATTERN "*.so*"
)


install(
    DIRECTORY
        "${CLAVIS_SOURCE_ROOT}/Common"
        "${CLAVIS_SOURCE_ROOT}/Components"
        "${CLAVIS_SOURCE_ROOT}/Modules"
        "${CLAVIS_SOURCE_ROOT}/Services"
        "${CLAVIS_SOURCE_ROOT}/Widgets"
    DESTINATION "${CLAVIS_CONFIG_INSTALL_DIR}"
    PATTERN "*.qmlc" EXCLUDE
)
install(
    FILES
        "${CLAVIS_SOURCE_ROOT}/shell.qml"
        "${CLAVIS_SOURCE_ROOT}/AppShell.qml"
    DESTINATION "${CLAVIS_CONFIG_INSTALL_DIR}"
)
install(
    DIRECTORY "${CLAVIS_SOURCE_ROOT}/assets/"
    DESTINATION "${CLAVIS_CONFIG_INSTALL_DIR}/assets"
)
install(
    DIRECTORY "${CLAVIS_SOURCE_ROOT}/scripts/"
    DESTINATION "${CLAVIS_CONFIG_INSTALL_DIR}/scripts"
    USE_SOURCE_PERMISSIONS
    PATTERN "__pycache__" EXCLUDE
    PATTERN "*.pyc" EXCLUDE
)
install(
    DIRECTORY "${CLAVIS_SOURCE_ROOT}/matugen/templates/"
    DESTINATION "${CLAVIS_CONFIG_INSTALL_DIR}/matugen/templates"
)
install(
    FILES "${CLAVIS_SOURCE_ROOT}/matugen/config.toml"
    DESTINATION "${CLAVIS_CONFIG_INSTALL_DIR}/matugen"
)

install(
    FILES "${CLAVIS_SOURCE_ROOT}/packaging/systemd/user/clavis-shell.service"
    DESTINATION "${CLAVIS_SYSTEMD_USER_INSTALL_DIR}"
)

install(DIRECTORY "${CLAVIS_SOURCE_ROOT}/licenses/"
    DESTINATION "${CLAVIS_CONFIG_INSTALL_DIR}/licenses")
install(FILES "${CLAVIS_SOURCE_ROOT}/LICENSE"
    DESTINATION "${CLAVIS_CONFIG_INSTALL_DIR}")
