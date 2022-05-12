cmake_minimum_required(VERSION 3.23)

project(nsew)

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



