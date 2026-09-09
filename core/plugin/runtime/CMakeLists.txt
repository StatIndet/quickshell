qt_add_library(ClavisRuntime SHARED)

set_target_properties(ClavisRuntime PROPERTIES
    LIBRARY_OUTPUT_DIRECTORY ${CLAVIS_QML_BUILD_DIR}/Clavis/Runtime
)

qt_add_qml_module(ClavisRuntime
    URI Clavis.Runtime
    SOURCES
        src/config_file_watch.h
        src/config_file_watch.cpp
        src/clavis_build_info.h
        src/clavis_build_info.cpp
        src/clavis_file_system.h
        src/clavis_file_system.cpp
    OUTPUT_DIRECTORY ${CLAVIS_QML_BUILD_DIR}/Clavis/Runtime
)

target_include_directories(ClavisRuntime PRIVATE
    src
    ${CMAKE_BINARY_DIR}/generated
)

target_link_libraries(ClavisRuntime PRIVATE
    Qt6::Core
    Qt6::Qml
)

qt_add_shaders(ClavisRuntime "clavis_palette_shaders"
    PREFIX "/clavis/shaders"
    BASE "${CLAVIS_SOURCE_ROOT}/assets/shaders"
    FILES "${CLAVIS_SOURCE_ROOT}/assets/shaders/zen-palette.frag"
)
