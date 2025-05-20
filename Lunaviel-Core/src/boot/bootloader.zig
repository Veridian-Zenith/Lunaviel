const std = @import("std");
const memory = @import("../memory/mem.zig");
const interrupts = @import("../kernel/interrupts.zig");
const kernel = @import("../kernel/main.zig");
const pulse = @import("../kernel/pulse.zig");
const hookt_fs = @import("../fs/hookt_fs.zig");
const nvme = @import("../drivers/nvme_driver.zig");
const cpu = @import("cpu.zig");

pub const BootInfo = struct {
    memory_map: []memory.MemoryMapEntry,
    kernel_physical_start: u64,
    kernel_virtual_start: u64,
    kernel_size: u64,
    system_pulse: pulse.SystemPulse,
    nvme_info: ?nvme.NVMeInfo,
};

var boot_info: BootInfo = undefined;

pub fn bootLunaviel() void {
    // Basic CPU initialization
    asm volatile ("cli");  // Disable interrupts
    cpu.initProcessor();   // Initialize processor features

    // Set up core system tables
    loadGDT();            // Load Global Descriptor Table
    loadIDT();            // Load Interrupt Descriptor Table

    // Map and initialize physical memory
    var memory_info = memory.initPhysicalMemory();
    boot_info.memory_map = memory_info.memory_map;
    boot_info.kernel_physical_start = memory_info.kernel_start;
    boot_info.kernel_virtual_start = KERNEL_VIRTUAL_BASE;
    boot_info.kernel_size = memory_info.kernel_size;

    // Initialize core systems
    memory.init();        // Initialize memory management
    interrupts.init();    // Initialize interrupt handling

    // Initialize system pulse
    boot_info.system_pulse = pulse.SystemPulse.init();

    // Detect and initialize NVMe devices
    if (nvme.detectDevices()) |nvme_info| {
        boot_info.nvme_info = nvme_info;
    } else |_| {
        boot_info.nvme_info = null;
    }

    // Enable interrupts and transfer to kernel
    asm volatile ("sti");
    kernel.kernel_main(&boot_info); // Transition to Lunaviel's core
}ootLunaviel() void {
    asm volatile ("cli");  // Disable interrupts
    loadGDT();             // Load Global Descriptor Table
    loadIDT();             // Load Interrupt Descriptor Table
    asm volatile ("sti");  // Enable interrupts

    kernel_main();         // Transition to Lunaviel’s core
}
