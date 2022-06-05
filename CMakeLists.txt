cmake_minimum_required(VERSION 3.22)

project(nsew)

include(CTest)
include(FetchContent)

option(NSEW_EXTERNAL_MAP "Build external map executable" ON)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_EXTENSIONS OFF)

file(GLOB_RECURSE LUA_FILES CONFIGURE_DEPENDS
    "NSEW/*.lua"
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

install(DIRECTORY NSEW DESTINATION ".")

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
        DESTINATION "NSEW/cdir/socket"
    )

    install(
        FILES
            ${luasocket_SOURCE_DIR}/src/socket.lua
            ${luasocket_SOURCE_DIR}/src/ltn12.lua
        DESTINATION "NSEW/ldir"
    )

    install(
        FILES
            ${luasocket_SOURCE_DIR}/src/http.lua
            ${luasocket_SOURCE_DIR}/src/tp.lua
            ${luasocket_SOURCE_DIR}/src/ftp.lua
            ${luasocket_SOURCE_DIR}/src/smtp.lua
            ${luasocket_SOURCE_DIR}/src/url.lua
        DESTINATION "NSEW/ldir/socket"
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

if (NSEW_EXTERNAL_MAP)
    add_subdirectory(external_map)
endif()

add_subdirectory(native)
add_subdirectory(server)
