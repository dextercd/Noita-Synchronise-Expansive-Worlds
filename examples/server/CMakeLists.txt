find_package(Boost 1.78 REQUIRED COMPONENTS
    system)

include(FetchContent)

add_executable(nsew_server
    main.cpp
)

target_link_libraries(nsew_server
    PRIVATE
        Boost::system
        absl::hash absl::flat_hash_map
        nsew_common
)

install(TARGETS nsew_server
    DESTINATION "server"
    COMPONENT NSEW_Server
)
