local socket = require("socket")
print(socket._VERSION)

-- create a TCP socket and bind it to the local host, at any port
local server = assert(socket.bind("*", 0))
-- find out which port the OS chose for us
local ip, port = server:getsockname()
-- print a message informing what's up
print("Opened socket localhost on port " .. port)
