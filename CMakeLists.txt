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
                --max-cyclomatic-complexity 15
                ${LUA_FILES}
    )
endif()

find_program(STYLUA NAMES stylua)

if (STYLUA)
    set(STYLUA_OPTIONS
        ${STYLUA} NSEW/
    )

    add_custom_target(stylua-reformat
        VERBATIM
        COMMAND ${STYLUA_OPTIONS} --verify
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    )

    add_custom_target(stylua-check
        VERBATIM
        COMMAND ${STYLUA_OPTIONS} --check
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    )
endif()



