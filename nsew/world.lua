--- World read / write functionality.
-- @module nsew.world
local world = {}

local ffi = require("ffi")
local world_ffi = require("nsew.world_ffi")

local C = ffi.C

ffi.cdef([[

enum ENCODE_CONST {
    PIXEL_RUN_MAX = 4096,
};

struct __attribute__ ((__packed__)) EncodedAreaHeader {
    int32_t x;
    int32_t y;
    uint8_t width;
    uint8_t height;

    uint16_t pixel_run_count;
};

struct __attribute__ ((__packed__)) PixelRun {
    uint16_t length;
    int16_t material;
};

struct __attribute__ ((__packed__)) EncodedArea {
    struct EncodedAreaHeader header;
    struct PixelRun pixel_runs[PIXEL_RUN_MAX];
};

]])

world.EncodedAreaHeader = ffi.typeof("struct EncodedAreaHeader")
world.PixelRun = ffi.typeof("struct PixelRun")
world.EncodedArea = ffi.typeof("struct EncodedArea")

--- Total bytes taken up by the encoded area
-- @tparam EncodedArea encoded_area
-- @treturn int total number of bytes that encodes the area
-- @usage
-- local data = ffi.string(area, world.encoded_size(area))
-- peer:send(data)
function world.encoded_size(encoded_area)
    return (ffi.sizeof(world.EncodedAreaHeader) + encoded_area.header.pixel_run_count * ffi.sizeof(world.PixelRun))
end

--- Encode the given rectangle of the world
-- The rectangle defined by {`start_x`, `start_y`, `end_x`, `end_y`} must not
-- exceed 256 in width or height.
-- @param chunk_map
-- @tparam int start_x coordinate
-- @tparam int start_y coordinate
-- @tparam int end_x coordinate
-- @tparam int end_y coordinate
-- @tparam EncodedArea encoded_area memory to use, if nil this function allocates its own memory
-- @return returns an EncodedArea or nil if the area could not be encoded
-- @see decode
function world.encode_area(chunk_map, start_x, start_y, end_x, end_y, encoded_area)
    start_x = ffi.cast('int32_t', start_x)
    start_y = ffi.cast('int32_t', start_y)
    end_x = ffi.cast('int32_t', end_x)
    end_y = ffi.cast('int32_t', end_y)

    encoded_area = encoded_area or world.EncodedArea()

    local width = end_x - start_x
    local height = end_y - start_y

    if width <= 0 or height <= 0 then
        print("Invalid world part, negative dimension")
        return nil
    end

    if width > 256 or height > 256 then
        print("Invalid world part, dimension greater than 256")
        return nil
    end

    encoded_area.header.x = start_x
    encoded_area.header.y = start_y
    encoded_area.header.width = width - 1
    encoded_area.header.height = height - 1

    local current_run = encoded_area.pixel_runs[0]
    local current_material = 0
    local run_length = 0
    local run_count = 1

    local y = start_y
    while y < end_y do
        local x = start_x
        while x < end_x do
            local material_number = 0

            local ppixel = world_ffi.get_cell(chunk_map, x, y)
            if ppixel[0] ~= nil then
                local pixel = ppixel[0]

                if pixel.vtable.get_cell_type(pixel) ~= C.CELL_TYPE_SOLID then
                    local material_ptr = pixel.vtable.get_material(pixel)
                    material_number = world_ffi.get_material_id(material_ptr)
                end
            end

            if x == start_x and y == start_y then
                -- Initial run
                current_material = material_number
            elseif current_material ~= material_number then
                -- Next run
                current_run.material = current_material
                current_run.length = run_length

                if run_count == C.PIXEL_RUN_MAX then
                    print("Area too complicated to encode")
                    return nil
                end

                current_run = encoded_area.pixel_runs[run_count]
                run_count = run_count + 1

                current_material = material_number
                run_length = 0
            end

            run_length = run_length + 1

            x = x + 1
        end
        y = y + 1
    end

    current_run.material = current_material
    current_run.length = run_length

    encoded_area.header.pixel_run_count = run_count

    return encoded_area
end

local PixelRun_const_ptr = ffi.typeof("struct PixelRun const*")

--- Load an encoded area back into the world.
-- @param grid_world
-- @tparam EncodedAreaHeader header header of the encoded area
-- @tparam string received string that contains the pixel runs of the encoded area
-- @see encode_area
function world.decode(grid_world, header, received)
    local buffer = ffi.cast('char const*', received)
    local pixel_runs = ffi.cast(PixelRun_const_ptr, buffer)

    local chunk_map = grid_world.vtable.get_chunk_map(grid_world)

    local top_left_x = header.x
    local top_left_y = header.y
    local width = header.width + 1
    local height = header.height + 1
    local bottom_right_x = top_left_x + width
    local bottom_right_y = top_left_y + height

    local current_run_ix = 0
    local current_run = pixel_runs[current_run_ix]
    local new_material = current_run.material
    local left = current_run.length

    local y = top_left_y
    while y < bottom_right_y do
        local x = top_left_x
        while x < bottom_right_x do
            if world_ffi.chunk_loaded(chunk_map, x, y) then
                local ppixel = world_ffi.get_cell(chunk_map, x, y)
                local current_material = 0

                if ppixel[0] ~= nil then
                    local pixel = ppixel[0]
                    current_material = world_ffi.get_material_id(pixel.vtable.get_material(pixel))

                    if new_material ~= current_material then
                        world_ffi.remove_cell(grid_world, pixel, x, y, false)
                    end
                end

                if current_material ~= new_material and new_material ~= 0 then
                    ppixel[0] =
                        world_ffi.construct_cell(grid_world, x, y, world_ffi.get_material_ptr(new_material), nil)
                end
            end

            left = left - 1
            if left <= 0 then
                current_run_ix = current_run_ix + 1
                current_run = pixel_runs[current_run_ix]
                new_material = current_run.material
                left = current_run.length
            end

            x = x + 1
        end
        y = y + 1
    end
end

return world
