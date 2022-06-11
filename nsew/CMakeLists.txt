set(NSEW_BUILD "${CMAKE_CURRENT_BINARY_DIR}/nsew")
set(NSEW_BUILD "${NSEW_BUILD}" PARENT_SCOPE)

file(MAKE_DIRECTORY "${NSEW_BUILD}")

set(SOURCES
    game_patch.lua  load.lua  native_dll.lua  world_ffi.lua  world.lua
)

foreach(source IN LISTS SOURCES)
    configure_file(${source} "${NSEW_BUILD}" COPYONLY)
endforeach()

install(DIRECTORY "${NSEW_BUILD}"
    DESTINATION "."
    COMPONENT nsew_lib
)

set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${NSEW_BUILD}")
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY "${NSEW_BUILD}")


if (WIN32)
    add_library(nsew_native MODULE
        game_pause_patch.cpp
    )

    include(GenerateExportHeader)
    generate_export_header(nsew_native)
    target_include_directories(nsew_native PRIVATE "${CMAKE_CURRENT_BINARY_DIR}")
endif()
