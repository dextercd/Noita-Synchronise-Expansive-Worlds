add_library(nsew_common INTERFACE)

target_include_directories(nsew_common
    INTERFACE include
)

if (BUILD_TESTING)
    add_subdirectory(tests)
endif()
