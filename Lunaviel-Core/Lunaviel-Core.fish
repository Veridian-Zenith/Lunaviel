#!/usr/bin/env fish

# 🌌 Lunaviel-Core.fish: Setup script for Lunaviel Core kernel (Fish Shell Compatible)

# Directories
mkdir -p aether memoria sylph astral seer scripts docs

# === Aether ===

printf "%s\n" '
const std = @import("std");
const uefi = std.uefi;

pub export fn efi_main(_: uefi.Handle, systab: *uefi.SystemTable) callconv(.C) uefi.Status {
    systab.con_out.output_string("🌌 Lunaviel Core Booting...\r\n").ok();
    const kernel_entry = @extern(*const fn () callconv(.C) void, .{ .name = "_start" });
    kernel_entry();
    return uefi.Status.SUCCESS;
}
' > aether/aurora.zig

printf "%s\n" '
ENTRY(_start)
OUTPUT_FORMAT(elf64-x86-64)
SECTIONS {
    . = 0x100000;
    .text : { *(.text) }
    .rodata : { *(.rodata) }
    .data : { *(.data) }
    .bss : { *(.bss) }
}
' > aether/starlight.ld

printf "%s\n" '
pub export fn _start() callconv(.C) noreturn {
    @import("luminary.zig").init();
    @import("etherial.zig").init();
    @import("harmonia.zig").init();

    const com1 = @intToPtr(*volatile u8, 0x3F8);
    com1.* = \'L\';
    com1.* = \'U\';
    com1.* = \'\\n\';

    while (true) {}
}
' > aether/sylvar.zig

printf "%s\n" '
pub fn init() void {
    asm volatile (
        \\ mov rax, cr0
        \\ and ax, 0xFFFB
        \\ or ax, 0x22
        \\ mov cr0, rax
        \\ mov rax, cr4
        \\ or rax, 0x40600
        \\ mov cr4, rax
    );
}
' > aether/luminary.zig

printf "%s\n" '
pub fn init() void {
    // IDT Initialization Stub
}
' > aether/etherial.zig

# === Memoria ===

printf "%s\n" '
pub fn init_paging() void {
    const page_table = @intToPtr(*volatile [512]u64, 0x1000);
    for (page_table) |*entry| {
        entry.* = 0;
    }
    page_table[0] = 0x83;
}
' > memoria/aetherpage.zig

printf "%s\n" '
var heap_start: usize = 0x200000;

pub fn alloc(size: usize) ?[*]u8 {
    const ptr = heap_start;
    heap_start += size;
    return @intToPtr([*]u8, ptr);
}
' > memoria/lunalloc.zig

printf "%s\n" '
pub fn init() void {
    @import("aetherpage.zig").init_paging();
}
' > memoria/harmonia.zig

# === Sylph ===

printf "%s\n" '
pub const Task = struct {
    id: u32,
    state: enum { Ready, Running, Blocked },
};

pub var current_task: Task = .{ .id = 0, .state = .Ready };
' > sylph/taskweave.zig

# === Astral ===

printf "%s\n" '
pub fn get_gop() ?u32 {
    return null;
}
' > astral/celestine.zig

# === Seer ===

printf "%s\n" '
pub fn log(msg: []const u8) void {
    const com1 = @intToPtr(*volatile u8, 0x3F8);
    for (msg) |c| {
        com1.* = c;
    }
    com1.* = \'\\n\';
}
' > seer/oracle.zig

# === Scripts ===

printf "%s\n" '
#!/usr/bin/fish
zig build-exe aether/aurora.zig -target x86_64-uefi -O ReleaseSmall -femit-bin=BOOTX64.EFI -fno-entry
zig build-exe aether/sylvar.zig -target x86_64-freestanding -T aether/starlight.ld -O ReleaseSmall -femit-bin=kernel.elf

dd if=/dev/zero of=lunaviel.img bs=1M count=64
mkfs.fat -F 32 lunaviel.img
mmd -i lunaviel.img ::/EFI/BOOT
mcopy -i lunaviel.img BOOTX64.EFI ::/EFI/BOOT/
mcopy -i lunaviel.img kernel.elf ::/
' > scripts/build.fish

printf "%s\n" '
#!/usr/bin/fish
qemu-system-x86_64 -drive format=raw,file=lunaviel.img -serial stdio -m 512 -cpu qemu64 -no-reboot -no-shutdown
' > scripts/run-qemu.fish

# === Docs ===

printf "%s\n" '
# Aether Phase - Boot and Initialization
Responsible for:
- UEFI Bootloader
- CPU Setup
- Early Memory Management
- Interrupt Descriptor Table
' > docs/aether.md

# Final Setup
chmod +x scripts/*.fish

echo "✅ Project initialized successfully!"
echo "👉 To build:   ./scripts/build.fish"
echo "👉 To run:     ./scripts/run-qemu.fish"
