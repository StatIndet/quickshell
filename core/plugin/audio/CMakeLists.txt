qt_add_library(ClavisAudio SHARED)

set_target_properties(ClavisAudio PROPERTIES
    LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/Clavis/Audio
)

qt_add_qml_module(ClavisAudio
    URI Clavis.Audio
    VERSION 1.0
    SOURCES
        src/cava_provider.h
        src/cava_provider.cpp
        src/audio_level_provider.h
        src/audio_level_provider.cpp
    OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/Clavis/Audio
)

target_include_directories(ClavisAudio PUBLIC src)

target_link_libraries(ClavisAudio PRIVATE
    ClavisAudioCore
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    PkgConfig::Cava
)
