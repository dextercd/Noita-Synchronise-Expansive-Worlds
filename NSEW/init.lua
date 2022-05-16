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

struct Cell {
    unsigned vtable;
    int hp;
    int unknown[3];
    unsigned material_ptr;
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

typedef struct Cell** __thiscall get_pixel_f(struct ChunkMap* this, int x, int y);

struct __attribute__ ((__packed__)) pixel_message {
    char col[3];
};

uint32_t GetCurrentThreadId();

]])

local get_pixel = ffi.cast("get_pixel_f*", 0x07bf560)

function get_grid_world()
    local game_global = ffi.cast("void**", 0x100d558)[0]
    local world_data = ffi.cast("void**", ffi.cast("char*", game_global) + 0xc)[0]
    local grid_world = ffi.cast("struct GridWorld**", ffi.cast("char*", world_data) + 0x44)[0]
    return grid_world
end

local red = 0xff0000
local orange = 0xffa500
local yellow = 0xffff00
local green = 0x008000
local cyan = 0x00ffff
local blue = 0x0099ff
local violet = 0x9900ff

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

function get_cursor_position()
    local x, y = DEBUG_GetMouseWorld()
    return x, y
end

function OnWorldPreUpdate() 
    wake_up_waiting_threads(1) 
end

function send_world_part(chunk_map, connection, start_x, start_y, end_x, end_y)
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

            local pixel = get_pixel(chunk_map, x, y)
            if pixel[0] ~= nil then
                if pixel[0].vtable == 0xe1a45c then
                    message.col[0] = pixel[0].colour.r
                    message.col[1] = pixel[0].colour.g
                    message.col[2] = pixel[0].colour.b
                end
            end

            x = x + 1
        end
        y = y + 1
    end

    if pixel_count > 0 then
        local send_pc = ffi.new('uint32_t[4]', {start_x, start_y, end_x, end_y})
        local str = (
            ffi.string(send_pc, 4 * 4) ..
            ffi.string(messages, ffi.sizeof('struct pixel_message') * pixel_count)
        )

        local index = 1
        while index ~= #str do
            local new_index = connection:send(str, index)
            if new_index ~= #str then
                print("For str with total length " .. #str .. "We sent from index " .. index .. " new index " .. new_index)
            end
            index = new_index
        end
    end
end

function OnWorldPostUpdate()
    if connection == nil then
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

        send_world_part(chunk_map, connection, start_x - 1, start_y - 1, end_x + 1, end_y + 1)
    end
end


function dump_type_info(typ)
    print(typ .. ': ' .. ffi.sizeof(typ))
end

function OnPlayerSpawned(player_entity)
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
