find_package(Qt6 6.8 REQUIRED COMPONENTS WaylandClient DBus)
qt_add_library(ClavisGamma SHARED)
qt_add_qml_module(ClavisGamma
    URI Clavis.Gamma
    SOURCES src/gamma_backend.h src/gamma_backend.cpp src/gamma_curve.h src/gamma_curve.cpp
    OUTPUT_DIRECTORY ${CLAVIS_QML_BUILD_DIR}/Clavis/Gamma
)
set_target_properties(ClavisGamma PROPERTIES
    LIBRARY_OUTPUT_DIRECTORY ${CLAVIS_QML_BUILD_DIR}/Clavis/Gamma
    CXX_VISIBILITY_PRESET hidden
    VISIBILITY_INLINES_HIDDEN ON
)
qt_generate_wayland_protocol_client_sources(ClavisGamma PRIVATE_CODE
    FILES "${CMAKE_CURRENT_SOURCE_DIR}/protocols/wlr-gamma-control-unstable-v1.xml")
target_include_directories(ClavisGamma PRIVATE src)
target_link_libraries(ClavisGamma PRIVATE Qt6::Core Qt6::Gui Qt6::Qml Qt6::WaylandClient Qt6::DBus)
