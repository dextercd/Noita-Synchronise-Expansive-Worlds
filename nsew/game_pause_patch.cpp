#include <cstdint>
#include <iostream>

#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <memoryapi.h>

#include <nsew_native_export.h>

std::uint8_t nop2[] = {0x66, 0x90};

extern "C" NSEW_NATIVE_EXPORT bool nsew_disable_game_pause()
{
    // Patch the code that handles the escape menu user interface.
    // At this address there's normally a jump that skips over the game
    // simulation routines.
    // Relative short jump to the game simulate code. (0x0063d0a2)
    auto address = reinterpret_cast<std::uint8_t*>(0x0063d059);
    std::uint8_t patch[2]{0xeb, 0x47};

    auto restore_prot = DWORD{};
    auto prot_res = VirtualProtect(
        address,
        sizeof(patch),
        PAGE_EXECUTE_READWRITE,
        &restore_prot
    );

    if (prot_res == 0) {
        std::cerr << "VirtualProtect failed";
        return false;
    }

    std::copy(std::begin(patch), std::end(patch), address);

    auto discard = DWORD{};
    VirtualProtect(
        address,
        2,
        restore_prot,
        &discard
    );

    return true;
}
