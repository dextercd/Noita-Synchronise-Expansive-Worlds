set(NSEW_BUILD "${CMAKE_CURRENT_BINARY_DIR}/nsew")
set(NSEW_BUILD "${NSEW_BUILD}" PARENT_SCOPE)

file(MAKE_DIRECTORY "${NSEW_BUILD}")

configure_file(world_ffi.lua "${NSEW_BUILD}" COPYONLY)
configure_file(world.lua "${NSEW_BUILD}" COPYONLY)

install(DIRECTORY "${NSEW_BUILD}"
    DESTINATION "."
    COMPONENT nsew_lib
)
