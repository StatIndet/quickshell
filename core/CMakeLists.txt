cmake_minimum_required(VERSION 3.16)
project(ClavisCore VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
# globally enable MOC to parse Q_OBJECT macros
set(CMAKE_AUTOMOC ON)

# Find Qt 6 basics
find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml Network)
find_package(PkgConfig REQUIRED)
pkg_check_modules(Pipewire IMPORTED_TARGET libpipewire-0.3 REQUIRED)
pkg_check_modules(Cava IMPORTED_TARGET libcava QUIET)
if(NOT Cava_FOUND)
    pkg_check_modules(Cava IMPORTED_TARGET cava REQUIRED)
endif()
qt_standard_project_setup(REQUIRES 6.5)

# Base reusable logic
add_subdirectory(src)

# Quickshell plugins
add_subdirectory(plugin/sysmon)
add_subdirectory(plugin/weather)
add_subdirectory(plugin/weathermap)
add_subdirectory(plugin/niri)
add_subdirectory(plugin/audio)
add_subdirectory(plugin/media)
add_subdirectory(plugin/keyboard)
