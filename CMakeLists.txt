cmake_minimum_required(VERSION 3.22)

project(nsew
    VERSION 0.0.4
    DESCRIPTION "Noita mod library with advanced utilities"
    HOMEPAGE_URL "https://github.com/dextercd/Noita-Synchronise-Expansive-Worlds"
    LANGUAGES C CXX
)

include(CTest)
include(FetchContent)

option(NSEW_EXTERNAL_MAP "Build external map executable" ON)
option(NSEW_INCLUDE_EXAMPLE "Package examples" ON)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_EXTENSIONS OFF)

set(VISIBILITY_INLINES_HIDDEN ON)
set(C_VISIBILITY_PRESET hidden)
set(CXX_VISIBILITY_PRESET hidden)

file(GLOB_RECURSE LUA_FILES CONFIGURE_DEPENDS
    "nsew/*.lua"
    "examples/nsew_client/*.lua"
)

find_program(LUACHECK NAMES luacheck)

if (LUACHECK)
    add_custom_target(luacheck
        VERBATIM
        COMMAND
            ${LUACHECK}
                ${LUA_FILES}
    )
endif()

find_program(LUAFORMATTER NAMES lua-format)

if (LUAFORMATTER)
    add_custom_target(formatter-reformat
        VERBATIM
        COMMAND ${LUAFORMATTER} -i -- ${LUA_FILES}
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    )

    add_custom_target(formatter-check
        VERBATIM
        COMMAND ${LUAFORMATTER} --check -- ${LUA_FILES}
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    )
endif()

if (NSEW_PREBUILT_DOCS_DIR)
    install(DIRECTORY ${NSEW_PREBUILT_DOCS_DIR}/
        DESTINATION docs
        COMPONENT NSEW_Docs
    )
else()
    find_program(LDOC NAMES ldoc)
    if (LDOC)
        add_custom_target(nsew_docs
            VERBATIM
            WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
            COMMAND ${LDOC}
                --dir ${CMAKE_CURRENT_BINARY_DIR}/docs
                .
        )
        install(DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/docs/
            DESTINATION docs
            COMPONENT NSEW_Docs
        )
    endif()
endif()

if (WIN32)
    FetchContent_Declare(LuaSocket
        GIT_REPOSITORY https://github.com/lunarmodules/luasocket.git
        GIT_TAG 88c8a85cb6528232288ec590910b7a966aace52b # v3.0.0
    )

    FetchContent_MakeAvailable(LuaSocket)

    add_library(luasocket-socket MODULE
        ${luasocket_SOURCE_DIR}/src/luasocket.c
        ${luasocket_SOURCE_DIR}/src/timeout.c
        ${luasocket_SOURCE_DIR}/src/buffer.c
        ${luasocket_SOURCE_DIR}/src/io.c
        ${luasocket_SOURCE_DIR}/src/auxiliar.c
        ${luasocket_SOURCE_DIR}/src/compat.c
        ${luasocket_SOURCE_DIR}/src/options.c
        ${luasocket_SOURCE_DIR}/src/inet.c
        ${luasocket_SOURCE_DIR}/src/wsocket.c
        ${luasocket_SOURCE_DIR}/src/except.c
        ${luasocket_SOURCE_DIR}/src/select.c
        ${luasocket_SOURCE_DIR}/src/tcp.c
        ${luasocket_SOURCE_DIR}/src/udp.c
    )

    set_target_properties(luasocket-socket
        PROPERTIES
        OUTPUT_NAME core
        LIBRARY_OUTPUT_DIRECTORY socket
    )

    target_include_directories(luasocket-socket
        PRIVATE ${LUAJIT_COMPILED}/src
    )

    target_link_libraries(luasocket-socket
        PRIVATE ${LUAJIT_COMPILED}/src/lua51.lib ws2_32.lib
    )

    install(
        TARGETS luasocket-socket
        DESTINATION "nsew_client/cdir/socket"
        COMPONENT NSEW_Client
    )

    install(
        FILES
            ${luasocket_SOURCE_DIR}/src/socket.lua
            ${luasocket_SOURCE_DIR}/src/ltn12.lua
        DESTINATION "nsew_client/ldir"
        COMPONENT NSEW_Client
    )

    install(
        FILES
            ${luasocket_SOURCE_DIR}/src/http.lua
            ${luasocket_SOURCE_DIR}/src/tp.lua
            ${luasocket_SOURCE_DIR}/src/ftp.lua
            ${luasocket_SOURCE_DIR}/src/smtp.lua
            ${luasocket_SOURCE_DIR}/src/url.lua
        DESTINATION "nsew_client/ldir/socket"
        COMPONENT NSEW_Client
    )

    if (BUILD_TESTING)
        add_test(
            NAME load-luasocket
            COMMAND
                ${CMAKE_COMMAND} -E env
                    LUA_PATH=${luasocket_SOURCE_DIR}/src/?.lua
                    LUA_CPATH=${CMAKE_CURRENT_BINARY_DIR}/?.dll
                ${LUAJIT_COMPILED}/src/luajit load_luasocket.lua

            WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/test
        )
    endif()
endif()


FetchContent_Declare(googletest
    GIT_REPOSITORY https://github.com/google/googletest
    GIT_TAG main
)

# googletest has an optional Python dependency, but since we don't need that
# feature we can disable the search for Python. Searching for Python in my
# Windows VM takes about 20 seconds so this is a nice optimisation.
set(Python_FIND_IMPLEMENTATIONS "")

FetchContent_MakeAvailable(googletest)


FetchContent_Declare(absl
    GIT_REPOSITORY https://github.com/abseil/abseil-cpp
    GIT_TAG master
)

set(ABSL_PROPAGATE_CXX_STD ON CACHE BOOL "")
set(ABSL_USE_EXTERNAL_GOOGLETEST ON CACHE BOOL "")

FetchContent_MakeAvailable(absl)


if (NSEW_EXTERNAL_MAP)
    add_subdirectory(external_map)
endif()

add_subdirectory(nsew)
add_subdirectory(native)
add_subdirectory(examples)

add_subdirectory(packaging)
