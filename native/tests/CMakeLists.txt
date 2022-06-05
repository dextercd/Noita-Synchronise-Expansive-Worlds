add_executable(test_serialise
    serialise.cpp
)

target_link_libraries(test_serialise PRIVATE nsew_common)

add_test(NAME TestSerialise COMMAND test_serialise)
