qt_add_library(ClavisKeyboard SHARED)

set_target_properties(ClavisKeyboard PROPERTIES
    LIBRARY_OUTPUT_DIRECTORY ${CLAVIS_QML_BUILD_DIR}/Clavis/Keyboard
)

qt_add_qml_module(ClavisKeyboard
    URI Clavis.Keyboard
    SOURCES
        src/shortcut_recorder.h
        src/shortcut_recorder.cpp
        src/keyboard_lock_plugin.h
        src/keyboard_lock_plugin.cpp
    OUTPUT_DIRECTORY ${CLAVIS_QML_BUILD_DIR}/Clavis/Keyboard
)

target_include_directories(ClavisKeyboard PUBLIC src)

pkg_check_modules(XkbCommon REQUIRED IMPORTED_TARGET xkbcommon)

target_link_libraries(ClavisKeyboard PRIVATE
    Qt6::Quick
    Qt6::Gui
    PkgConfig::XkbCommon
    Qt6::Core
    Qt6::Qml
)
