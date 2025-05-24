// aether/sylvar.zig
pub export fn _start() callconv(.C) noreturn {
    @import("luminary.zig").init(); // CPU setup
    @import("etherial.zig").init(); // Interrupts

    // Print to framebuffer (UEFI GOP already initialized)
    if (@import("astral/celestine.zig").get_gop()) |gop| {
        gop.draw_text(10, 10, "✨ Lunaviel Core Active", 0x00FFFFFF);
    }

    while (true) {}
}
