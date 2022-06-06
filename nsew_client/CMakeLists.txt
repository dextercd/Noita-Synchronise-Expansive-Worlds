install(DIRECTORY nsew_client
    DESTINATION "."
    COMPONENT nsew_client
)

install(DIRECTORY "${NSEW_BUILD}"
    DESTINATION "nsew_client/deps"
    COMPONENT nsew_client
)
