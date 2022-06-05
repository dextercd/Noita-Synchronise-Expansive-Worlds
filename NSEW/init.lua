dofile( "data/scripts/lib/coroutines.lua" )

package.path = package.path .. ";.\\mods\\NSEW\\ldir\\?.lua"
package.cpath = package.cpath .. ";.\\mods\\NSEW\\cdir\\?.dll"

local ffi = require("ffi")
local C = ffi.C

local socket = require("socket")

local connection = nil

ffi.cdef([[

typedef void* __thiscall placeholder_memfn(void*);

struct Position {
    int x;
    int y;
};

struct colour {
    uint8_t r;
    uint8_t g;
    uint8_t b;
    uint8_t a;
};

struct AABB {
    struct Position top_left;
    struct Position bottom_right;
};

enum CellType {
    CELL_TYPE_NONE = 0,
    CELL_TYPE_LIQUID = 1,
    CELL_TYPE_GAS = 2,
    CELL_TYPE_SOLID = 3,
    CELL_TYPE_FIRE = 4,
};

struct Cell_vtable {
    void (__thiscall *destroy)(struct Cell*, char dealloc);
    enum CellType (__thiscall *get_cell_type)(struct Cell*);
    void* field2_0x8;
    void* field3_0xc;
    void* field4_0x10;
    struct colour (__thiscall *get_colour)(struct Cell*);
    void* field6_0x18;
    void (__thiscall *set_colour)(struct Cell*, struct colour);
    void* field8_0x20;
    void* field9_0x24;
    void* field10_0x28;
    void* field11_0x2c;
    void* (__thiscall *get_material)(void *);
    void* gm;
    void* field13_0x34;
    void* field14_0x38;
    void* field15_0x3c;
    void* field16_0x40;
    void* field17_0x44;
    void* field18_0x48;
    void* field19_0x4c;
    //position * (* get_position)(void *, struct position *);
    void* gp;
    void* field21_0x54;
    void* field22_0x58;
    void* field23_0x5c;
    void* field24_0x60;
    void* field25_0x64;
    void* field26_0x68;
    void* field27_0x6c;
    void* field28_0x70;
    void* field29_0x74;
    void* field30_0x78;
    void* field31_0x7c;
    void* field32_0x80;
    void* field33_0x84;
    void* field34_0x88;
    void* field35_0x8c;
    void* field36_0x90;
    void* field37_0x94;
    void* field38_0x98;
    void (__thiscall *remove)(struct Cell*);
    void* field40_0xa0;
};

struct Cell {
    struct Cell_vtable* vtable;
    int hp;
    int unknown[3];
    uintptr_t material_ptr;
    int x;
    int y;
    int unknown2[4];
    struct colour colour;
    unsigned not_colour;
};

typedef struct Cell (*cell_array)[0x40000];

struct ChunkMap {
    int unknown[2];
    cell_array* (*cells)[0x40000];
    int unknown2[8];
};

struct GridWorld_vtable {
    placeholder_memfn* unknown[3];
    struct ChunkMap* (__thiscall *get_chunk_map)(struct GridWorld* this);
    placeholder_memfn* unknown2[30];
};

struct GridWorld {
    struct GridWorld_vtable* vtable;
    int unknown[318];
    int world_update_count;
    struct ChunkMap chunk_map;
    int unknown2[41];
    struct GridWorldThreadImpl* mThreadImpl;
};

struct GridWorldThreaded_vtable;

struct GridWorldThreaded {
    struct GridWorldThreaded_vtable* vtable;
    int unknown[287];
    struct AABB update_region;
};

struct vec_pGridWorldThreaded {
    struct GridWorldThreaded** begin;
    struct GridWorldThreaded** end_;
    struct GridWorldThreaded** capacity_end;
};

struct WorldUpdateParams {
    struct AABB update_region;
    int unknown;
    struct GridWorldThreaded* grid_world_threaded;
};

struct vec_WorldUpdateParams {
    struct WorldUpdateParams* begin;
    struct WorldUpdateParams* end_;
    struct WorldUpdateParams* capacity_end;
};

struct GridWorldThreadImpl {
    int chunk_update_count;
    struct vec_pGridWorldThreaded updated_grid_worlds;

    int world_update_params_count;
    struct vec_WorldUpdateParams world_update_params;

    int grid_with_area_count;
    struct vec_pGridWorldThreaded with_area_grid_worlds;

    int another_count;
    int another_vec[3];

    int some_kind_of_ptr;
    int some_kind_of_counter;

    int last_vec[3];
};

typedef struct Cell** __thiscall get_pixel_f(struct ChunkMap*, int x, int y);
typedef bool __thiscall chunk_loaded_f(struct ChunkMap*, int x, int y);

typedef void __thiscall remove_cell_f(struct GridWorld*, void* cell, int x, int y, bool);
typedef struct Cell* __thiscall construct_cell_f(struct GridWorld*, int x, int y, void* material_ptr, void* memory);

struct __attribute__ ((__packed__)) pixel_message {
    uint16_t material;
};

uint32_t GetCurrentThreadId();

void* malloc(size_t);
void free(void*);

]])

local get_pixel = ffi.cast("get_pixel_f*", 0x07bf560)
local remove_cell = ffi.cast("remove_cell_f*", 0x6a83c0)
local construct_cell = ffi.cast("construct_cell_f*", 0x691b70)
local chunk_loaded = ffi.cast("chunk_loaded_f*", 0x7bf440)

function get_grid_world()
    local game_global = ffi.cast("void**", 0x100d558)[0]
    local world_data = ffi.cast("void**", ffi.cast("char*", game_global) + 0xc)[0]
    local grid_world = ffi.cast("struct GridWorld**", ffi.cast("char*", world_data) + 0x44)[0]
    return grid_world
end

function set_colour(grid_world, x, y, col)
    local chunk_map = grid_world.vtable.get_chunk_map(grid_world)
    local ppixel = get_pixel(chunk_map, x, y)
    if ppixel[0] == nil then
        return
    end

    if ppixel[0].vtable ~= 0xe1a45c then
        return
    end

    -- the colour fields is argb using individual bytes. But the definition we
    -- use in this code here type-puns it to a little endian integer. Reorder
    -- the bytes so the colour is correct
    col = bit.rshift(bit.bswap(col), 8)

    ppixel[0].colour = bit.bor(bit.band(ppixel[0].colour, 0xff000000), col)
    -- ppixel[0].material_ptr = get_material_ptr(124)
    -- ppixel[0].meh2 = 0x1

    -- print(ppixel[0].material_ptr)
end

function get_player()
    return EntityGetWithTag("player_unit")[1]
end

function get_cursor_position()
    local x, y = DEBUG_GetMouseWorld()
    return x, y
end

function left_pressed()
    local control = EntityGetFirstComponent(get_player(), "ControlsComponent")
    return (
        ComponentGetValue2(control, "mButtonDownFire") and
        ComponentGetValue2(control, "mButtonDownFire2")
    )
end

function right_pressed()
    local control = EntityGetFirstComponent(get_player(), "ControlsComponent")
    return ComponentGetValue2(control, "mButtonDownThrow")
end

local material_props_size = 0x28c
function get_material_ptr(id)
    local game_global = ffi.cast("char**", 0x100d558)[0]
    local cell_factory = ffi.cast('char**', (game_global + 0x18))[0]
    local count = tonumber(ffi.cast('unsigned*', cell_factory + 0x24)[0])
    local begin = ffi.cast('char**', cell_factory + 0x18)[0]
    local ptr = begin + material_props_size * id
    return ptr
end

function get_material_id(ptr)
    local game_global = ffi.cast("char**", 0x100d558)[0]
    local cell_factory = ffi.cast('char**', (game_global + 0x18))[0]
    local begin = ffi.cast('char**', cell_factory + 0x18)[0]
    local offset = ffi.cast('char*', ptr) - begin
    return offset / material_props_size
end

ModMagicNumbersFileAdd("mods/NSEW/files/magic_numbers.xml")

function OnWorldPreUpdate()
    wake_up_waiting_threads(1)

    if true then
        return
    end

    local material1 = nil
    local material2 = nil

    if left_pressed() then
        material1 = get_material_ptr(CellFactory_GetType("gold"))
        material2 = get_material_ptr(CellFactory_GetType("templebrick_static"))
    elseif right_pressed() then
        material1 = get_material_ptr(CellFactory_GetType("fire"))
        material2 = get_material_ptr(CellFactory_GetType("fire_blue"))
    else
        return
    end

    local grid_world = get_grid_world()
    local chunk_map = grid_world.vtable.get_chunk_map(grid_world)

    local ax, ay = get_cursor_position()

    local xrange = 3
    local yrange = 10
    for y=ay - yrange, ay + yrange do
        for x=ax - xrange, ax + xrange do
            local ppixel = get_pixel(chunk_map, x, y)
            local pixel = nil

            if ppixel[0] ~= nil then
                pixel = ppixel[0]
                if pixel.material_ptr ~= ffi.cast("uintptr_t", material2) then
                    remove_cell(grid_world, pixel, x, y, false)
                    pixel = construct_cell(grid_world, x, y, material1, nil)
                end
            else
                pixel = construct_cell(grid_world, x, y, material2, nil)
            end

            if pixel then
                ppixel[0] = pixel
            end
        end
    end
end

function send_world_part(chunk_map, connection, start_x, start_y, end_x, end_y)
    start_x = ffi.cast('int32_t', start_x)
    start_y = ffi.cast('int32_t', start_y)
    end_x = ffi.cast('int32_t', end_x)
    end_y = ffi.cast('int32_t', end_y)

    local width = end_x - start_x
    local pixel_count = width * (end_y - start_y)
    local messages = ffi.new('struct pixel_message[?]', pixel_count)

    if pixel_count <= 0 then
        return
    end

    if start_y > end_y then
        return
    end

    if start_x > end_x then
        return
    end

    local y = start_y
    while y < end_y do
        local x = start_x
        while x < end_x do
            local pixel_index = (y - start_y) * width + (x - start_x)
            local message = messages[pixel_index]

            local ppixel = get_pixel(chunk_map, x, y)
            if ppixel[0] ~= nil then
                local pixel = ppixel[0]
                --if pixel.vtable.get_cell_type(pixel) ~= C.CELL_TYPE_SOLID then
                    local material_ptr = pixel.vtable.get_material(pixel)
                    message.material = get_material_id(material_ptr)
                --end
            end

            x = x + 1
        end
        y = y + 1
    end

    if pixel_count > 0 then
        local send_pc = ffi.new('int32_t[4]', {start_x, start_y, end_x, end_y})

        local str = (
            ffi.string(send_pc, 4 * 4) ..
            ffi.string(messages, ffi.sizeof('struct pixel_message') * pixel_count)
        )

        local index = 1
        while index ~= #str do
            connection:settimeout(nil)
            local new_index, err, partial_index = connection:send(str, index)
            if new_index == nil then
                print("For str with total length " .. #str .. "We sent from index " .. index .. " new index " .. partial_index)
                print("Error " .. err)
                index = partial_index
            else
                index = new_index
            end
        end
    end
end

function process_data(top_left_x, top_left_y, bottom_right_x, bottom_right_y, received)
    local buffer = ffi.cast('const char*', received)
    local messages = ffi.cast('struct pixel_message*', buffer)

    local grid_world = get_grid_world()
    local chunk_map = grid_world.vtable.get_chunk_map(grid_world)

    local width = bottom_right_x - top_left_x

    local y = top_left_y
    while y < bottom_right_y do
        local x = top_left_x
        while x < bottom_right_x do
            local pixel_index = (y - top_left_y) * width + (x - top_left_x)
            local message = messages[pixel_index]

            if chunk_loaded(chunk_map, x, y) then
                local ppixel = get_pixel(chunk_map, x, y)
                local current_material = 0

                if ppixel[0] ~= nil then
                    local pixel = ppixel[0]
                    current_material = get_material_id(pixel.vtable.get_material(pixel))

                    if message.material ~= current_material then
                        remove_cell(grid_world, pixel, x, y, false)
                    end
                end

                if current_material ~= message.material and message.material ~= 0 then
                    ppixel[0] = construct_cell(
                        grid_world, x, y, get_material_ptr(message.material), nil)
                end
            end

            x = x + 1
        end
        y = y + 1
    end
end

local receive_top_left_x = nil
local receive_top_left_y = nil
local receive_bottom_right_x = nil
local receive_bottom_right_y = nil
local partial = ''

function do_receive()
    while receive_one() do end
end

function receive_one()
    if receive_top_left_x == nil then
        connection:settimeout(0)
        local received, err, part = connection:receive(4 * 4 - #partial)
        if received == nil then
            partial = partial .. part
            return false
        end

        received = partial .. received
        partial = ''

        local header = ffi.cast('const char*', received)
        local coords = ffi.cast('const int32_t*', header)
        receive_top_left_x = coords[0]
        receive_top_left_y = coords[1]
        receive_bottom_right_x = coords[2]
        receive_bottom_right_y = coords[3]
    end

    local width = receive_bottom_right_x - receive_top_left_x
    local height = receive_bottom_right_y - receive_top_left_y
    local size = width * height
    local data_left = 2 * size - #partial

    local received, err, part = connection:receive(tonumber(data_left))
    if received == nil then
        partial = partial .. part
        return false
    end

    received = partial .. received

    process_data(
        receive_top_left_x,
        receive_top_left_y,
        receive_bottom_right_x,
        receive_bottom_right_y,
        received
    )

    receive_top_left_x = nil
    receive_top_left_y = nil
    receive_bottom_right_x = nil
    receive_bottom_right_y = nil
    partial = ''

    return true
end

function OnWorldPostUpdate()
    if connection == nil then
        return
    end

    if os.getenv("ROLE") == "R" then
        do_receive()
        return
    end

    local grid_world = get_grid_world()
    local chunk_map = grid_world.vtable.get_chunk_map(grid_world)
    local thread_impl = grid_world.mThreadImpl

    local begin = thread_impl.updated_grid_worlds.begin
    local end_ = begin + thread_impl.chunk_update_count

    local count = thread_impl.chunk_update_count

    for i=0, count - 1 do
        local it = begin[i]

        local start_x = it.update_region.top_left.x
        local start_y = it.update_region.top_left.y
        local end_x = it.update_region.bottom_right.x
        local end_y = it.update_region.bottom_right.y

        send_world_part(chunk_map, connection, start_x - 1, start_y - 1, end_x + 1, end_y + 2)
    end
end


function dump_type_info(typ)
    print(typ .. ': ' .. ffi.sizeof(typ))
end

function OnPlayerSpawned(player_entity)
    if true then
        return
    end
    async(function()
        -- Only the changed world data gets sent, which isn't very interesting to look at,
        -- so just send a bunch of data around the player

        -- Ensure chunks are loaded around the player
        wait(60)

        local grid_world = get_grid_world()
        local chunk_map = grid_world.vtable.get_chunk_map(grid_world)

        for y=-2048,2048,64 do
            for x=-2048,2048,64 do
                send_world_part(chunk_map, connection, x, y, x + 64, y + 64)
            end
        end
    end)
end

print(socket._VERSION)

local master = socket.tcp()
local connect_res = assert(master:connect('127.0.0.1', 44174))
connection = master
