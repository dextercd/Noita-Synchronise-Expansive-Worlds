find_package(Boost 1.78 REQUIRED COMPONENTS
    system)

include(FetchContent)

FetchContent_Declare(absl
    GIT_REPOSITORY https://github.com/abseil/abseil-cpp
    GIT_TAG master
)

set(ABSL_PROPAGATE_CXX_STD ON)

FetchContent_MakeAvailable(absl)

add_executable(nsew_server
    main.cpp
)

target_link_libraries(nsew_server
    PRIVATE
        Boost::system
        absl::hash absl::flat_hash_map
        nsew_common
)
