const std = @import("std");
const log = @import("../seer/oracle.zig").log;

// GDT entry structure
const GDTEntry = packed struct {
    limit_low: u16,
    base_low: u16,
    base_middle: u8,
    access: u8,
    granularity: u8,
    base_high: u8,
};

// GDT pointer structure
const GDTPointer = packed struct {
    limit: u16,
    base: u64,
};

// Segment selectors
pub const KERNEL_CS: u16 = 0x08;
pub const KERNEL_DS: u16 = 0x10;
pub const USER_CS: u16 = 0x18 | 3; // Ring 3
pub const USER_DS: u16 = 0x20 | 3; // Ring 3
pub const TSS_SEG: u16 = 0x28;

// CPU feature detection and control
const CPUFeatures = packed struct {
    has_avx: bool = false,
    has_avx2: bool = false,
    has_sse4_2: bool = false,
    has_aes: bool = false,
    has_hybrid_cores: bool = false,
    max_hybrid_cores: u32 = 0,
};

var gdt: [8]GDTEntry align(8) = undefined;
var gdt_pointer: GDTPointer = undefined;
var cpu_features: CPUFeatures = undefined;

pub fn init() void {
    // Setup GDT entries
    setup_gdt_entries();

    // Detect CPU features
    detect_cpu_features();

    // Load GDT
    load_gdt();

    // Initialize TSS
    setup_tss();

    log("GDT and CPU features initialized");
}

fn setup_gdt_entries() void {
    // Null descriptor
    gdt[0] = GDTEntry{
        .limit_low = 0,
        .base_low = 0,
        .base_middle = 0,
        .access = 0,
        .granularity = 0,
        .base_high = 0,
    };

    // Kernel code segment
    gdt[1] = GDTEntry{
        .limit_low = 0xFFFF,
        .base_low = 0,
        .base_middle = 0,
        .access = 0x9A,      // Present, Ring 0, Code
        .granularity = 0xAF, // 4KB blocks, 64-bit
        .base_high = 0,
    };

    // Kernel data segment
    gdt[2] = GDTEntry{
        .limit_low = 0xFFFF,
        .base_low = 0,
        .base_middle = 0,
        .access = 0x92,      // Present, Ring 0, Data
        .granularity = 0xCF, // 4KB blocks
        .base_high = 0,
    };

    // User code segment
    gdt[3] = GDTEntry{
        .limit_low = 0xFFFF,
        .base_low = 0,
        .base_middle = 0,
        .access = 0xFA,      // Present, Ring 3, Code
        .granularity = 0xAF, // 4KB blocks, 64-bit
        .base_high = 0,
    };

    // User data segment
    gdt[4] = GDTEntry{
        .limit_low = 0xFFFF,
        .base_low = 0,
        .base_middle = 0,
        .access = 0xF2,      // Present, Ring 3, Data
        .granularity = 0xCF, // 4KB blocks
        .base_high = 0,
    };

    // TSS entry will be set up later

    // Set up GDT pointer
    gdt_pointer = GDTPointer{
        .limit = @sizeOf(@TypeOf(gdt)) - 1,
        .base = @ptrToInt(&gdt),
    };
}

fn detect_cpu_features() void {
    var max_cpuid: u32 = undefined;
    var vendor: [12]u8 = undefined;

    // Get maximum CPUID function
    asm volatile ("cpuid"
        : [max] "={eax}" (max_cpuid),
          [ebx] "={ebx}" (vendor[0]),
          [edx] "={edx}" (vendor[4]),
          [ecx] "={ecx}" (vendor[8])
        : [leaf] "{eax}" (0)
    );

    if (max_cpuid >= 7) {
        var eax: u32 = undefined;
        var ebx: u32 = undefined;
        var ecx: u32 = undefined;
        var edx: u32 = undefined;

        // Get CPU features
        asm volatile ("cpuid"
            : [eax] "={eax}" (eax),
              [ebx] "={ebx}" (ebx),
              [ecx] "={ecx}" (ecx),
              [edx] "={edx}" (edx)
            : [leaf] "{eax}" (7),
              [subleaf] "{ecx}" (0)
        );

        cpu_features = CPUFeatures{
            .has_avx2 = (ebx & (1 << 5)) != 0,
            .has_avx = (ecx & (1 << 28)) != 0,
            .has_sse4_2 = (ecx & (1 << 20)) != 0,
            .has_aes = (ecx & (1 << 25)) != 0,
            .has_hybrid_cores = (edx & (1 << 15)) != 0,
            .max_hybrid_cores = if ((edx & (1 << 15)) != 0) 8 else 0,
        };
    }
}

fn load_gdt() void {
    asm volatile ("lgdt [%[gdt_ptr]]"
        :
        : [gdt_ptr] "r" (&gdt_pointer)
    );

    // Reload segment registers
    asm volatile (
        \\push %[selector]
        \\lea 1f(%%rip), %%rax
        \\push %%rax
        \\retfq
        \\1:
        \\mov %[ds], %%ax
        \\mov %%ax, %%ds
        \\mov %%ax, %%es
        \\mov %%ax, %%fs
        \\mov %%ax, %%gs
        \\mov %%ax, %%ss
        :
        : [selector] "i" (KERNEL_CS),
          [ds] "i" (KERNEL_DS)
        : "rax", "memory"
    );
}
    var size: usize = 0;
    var map: [*]uefi.tables.MemoryDescriptor = undefined;
    var map_key: usize = undefined;
    var descriptor_size: usize = undefined;
    var descriptor_version: u32 = undefined;

    // Get the memory map size first
    _ = boot_services.getMemoryMap(&size, map, &map_key, &descriptor_size, &descriptor_version);

    // Allocate memory for the map
    const pool_alloc = try boot_services.allocatePool(uefi.tables.MemoryType.BootServicesData, size);
    map = @ptrCast([*]uefi.tables.MemoryDescriptor, @alignCast(@alignOf(uefi.tables.MemoryDescriptor), pool_alloc));

    // Get the actual memory map
    _ = try boot_services.getMemoryMap(&size, map, &map_key, &descriptor_size, &descriptor_version);

    return map[0..size / descriptor_size];
}

pub fn setup_graphics(boot_services: *uefi.tables.BootServices) !void {
    var gop: *anyopaque = undefined;
    _ = try boot_services.locateProtocol(
        &EFI_GRAPHICS_OUTPUT_PROTOCOL_GUID,
        null,
        &gop,
    );

    // TODO: Set preferred graphics mode
}

pub export fn efi_main(handle: uefi.Handle, systab: *uefi.SystemTable) callconv(.C) uefi.Status {
    systab.con_out.outputString("🌌 Lunaviel Core Booting...\r\n").ok();
    systab.con_out.outputString("📊 Setting up graphics mode...\r\n").ok();

    setup_graphics(systab.boot_services) catch {
        systab.con_out.outputString("❌ Failed to setup graphics\r\n").ok();
        return .LoadError;
    };

    systab.con_out.outputString("🗺️ Getting memory map...\r\n").ok();
    const memory_map = get_memory_map(systab.boot_services) catch {
        systab.con_out.outputString("❌ Failed to get memory map\r\n").ok();
        return .LoadError;
    };

    systab.con_out.outputString("🚀 Jumping to kernel...\r\n").ok();
    const kernel_entry = @extern(*const fn () callconv(.C) void, .{ .name = "_start" });
    kernel_entry();

    return .Success;
}
