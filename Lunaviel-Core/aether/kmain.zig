const std = @import("std");
const log = @import("../seer/oracle.zig").log;
const gdt = @import("aurora.zig");
const interrupts = @import("etherial.zig");
const memory = @import("../memoria/lunalloc.zig");
const scheduler = @import("../sylph/moonweave.zig");

// Multiboot information structure
const MultibootInfo = extern struct {
    flags: u32,
    mem_lower: u32,
    mem_upper: u32,
    boot_device: u32,
    cmdline: u32,
    mods_count: u32,
    mods_addr: u32,
    syms: [4]u32,
    mmap_length: u32,
    mmap_addr: u32,
    drives_length: u32,
    drives_addr: u32,
    config_table: u32,
    boot_loader_name: u32,
    apm_table: u32,
    vbe_control_info: u32,
    vbe_mode_info: u32,
    vbe_mode: u16,
    vbe_interface_seg: u16,
    vbe_interface_off: u16,
    vbe_interface_len: u16,
};

pub export fn kmain(multiboot_magic: u32, multiboot_info: *MultibootInfo) void {
    // Verify multiboot magic number
    if (multiboot_magic != 0x2BADB002) {
        log("Invalid multiboot magic number!");
        return;
    }

    // Early initialization
    gdt.init();                // Initialize Global Descriptor Table
    interrupts.init();         // Set up Interrupt Descriptor Table and handlers
    memory.init(multiboot_info); // Initialize memory management

    // Initialize system components
    var moon = scheduler.MoonScheduler.init();

    // Initialize hardware-specific features for i3-1215U
    const cpu_features = detectCPUFeatures();
    setupAdvancedFeatures(cpu_features);

    // Enter main kernel loop
    while (true) {
        moon.tick();
        handleInterrupts();
        moon.adjust_core_power();
    }
}

fn detectCPUFeatures() struct {
    avx2: bool,
    sse4_2: bool,
    aes: bool,
    tsx: bool,
} {
    var features = std.Target.x86.featureSet(.{});
    return .{
        .avx2 = features.hasFeature(.avx2),
        .sse4_2 = features.hasFeature(.sse4_2),
        .aes = features.hasFeature(.aes),
        .tsx = features.hasFeature(.tsx),
    };
}

fn setupAdvancedFeatures(features: anytype) void {
    // Enable available CPU features
    if (features.avx2) {
        // Enable AVX2 for enhanced vector operations
        enableAVX2();
    }
    if (features.aes) {
        // Enable AES-NI for hardware encryption
        enableAESNI();
    }
}

fn enableAVX2() void {
    // Enable AVX2 using XGETBV and XSETBV
    asm volatile ("xgetbv"
        : [ret] "={eax}" (-> u32),
        : [xcr] "{ecx}" (0)
    );
}

fn enableAESNI() void {
    // Enable AES-NI instructions
    asm volatile (""); // Placeholder - actual implementation would configure MSRs
}

fn handleInterrupts() void {
    // Process any pending interrupts
    interrupts.handle_pending();
}
