cmake_minimum_required(VERSION 3.21)

file(STRINGS "${CMAKE_CURRENT_SOURCE_DIR}/VERSION" PROJECT_DATE_VERSION LIMIT_COUNT 1)
set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/VERSION")
project(ClavisShell VERSION ${PROJECT_DATE_VERSION} LANGUAGES C CXX)

include(GNUInstallDirs)
include(CTest)

set(CLAVIS_QML_BUILD_DIR "${CMAKE_BINARY_DIR}/qml" CACHE PATH
    "Build-tree QML import root")
set(CLAVIS_QML_INSTALL_DIR "${CMAKE_INSTALL_LIBDIR}/qt6/qml" CACHE PATH
    "Install destination for Clavis private QML modules")
set(CLAVIS_CONFIG_INSTALL_DIR "etc/xdg/quickshell/clavis" CACHE PATH
    "Install destination for the Quickshell clavis configuration")
set(CLAVIS_SYSTEMD_USER_INSTALL_DIR "${CMAKE_INSTALL_LIBDIR}/systemd/user" CACHE PATH
    "Install destination for Clavis systemd user units")

add_subdirectory(core)
