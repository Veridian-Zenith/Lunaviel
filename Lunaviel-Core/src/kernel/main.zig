const std = @import("std");
const paging = @import("../mm/paging.zig");
const PhysicalMemoryManager = @import("../mm/physical_memory.zig").PhysicalMemoryManager;
const VirtualMemoryManager = @import("../mm/virtual_memory.zig").VirtualMemoryManager;
const heap = @import("../mm/heap.zig");
const syscall = @import("syscall.zig");
const ExecutionCore = @import("execution_core.zig").ExecutionCore;
const scheduler = @import("../process/scheduler.zig");
const pulse = @import("pulse.zig");

var phys_mem_manager: PhysicalMemoryManager = undefined;
var virt_mem_manager: VirtualMemoryManager = undefined;
var kernel_heap: heap.HeapAllocator = undefined;
var global_execution_core: ExecutionCore = undefined;

/// Get the global execution core instance
pub fn getExecutionCore() *ExecutionCore {
    return &global_execution_core;
}

/// The main kernel execution loop.
pub fn kernel_main() void {
    initMemoryManagement() catch |err| {
        // Handle initialization error
        @panic("Failed to initialize memory management");
    };

    // Initialize scheduler and system pulse
    var sched = scheduler.Scheduler.init();
    var sys_pulse = pulse.SystemPulse.init();

    // Initialize execution core
    global_execution_core = ExecutionCore.init(&sched, &sys_pulse);

    // Initialize system calls
    syscall.init();

    // Main kernel loop
    while (true) {
        global_execution_core.execute();
        stabilizeExecution();
        processEvents();
        adjustSystemLoad();
    }
}

/// Entry point required by the linker to start execution.
export fn _start() void {
    initialize_system();
    kernel_main();
}

/// Initializes core components before entering the main loop.
fn initialize_system() void {
    setup_memory();
    setup_interrupts();
    initDrivers(); // Initialize hardware drivers
}

/// Sets up basic memory structures.
fn setup_memory() void {
    // Placeholder: Define memory management logic here
}

/// Configures system interrupts.
fn setup_interrupts() void {
    loadIDT(); // Load the Interrupt Descriptor Table
}

/// Initializes hardware drivers.
pub fn initDrivers() void {
    whisper(0x60, 0x01); // Example hardware interaction
    whisper(0x64, 0x02); // Another example
}

pub fn init() void {
    mem_root = @alignCast(align_of(u8), @ptrCast([*]u8, 0x100000)); // Example address
}

fn initMemoryManagement() !void {
    // Initialize physical memory manager with bootloader-provided memory map
    const memory_bitmap_addr = 0x100000; // 1MB mark for bitmap storage
    phys_mem_manager = try PhysicalMemoryManager.init(getMemoryMap(), @intToPtr([*]u64, memory_bitmap_addr));

    // Create and initialize virtual memory manager
    const root_page_table = try phys_mem_manager.allocatePage() orelse return error.OutOfMemory;
    virt_mem_manager = try VirtualMemoryManager.init(&phys_mem_manager, root_page_table);

    // Map kernel sections
    try virt_mem_manager.mapRegion(.{
        .start = paging.KERNEL_VIRTUAL_BASE,
        .size = 16 * 1024 * 1024, // 16MB initial kernel space
        .flags = .{
            .writable = true,
            .executable = true,
        },
    }, 0x100000); // Map to physical 1MB+

    // Initialize kernel heap
    const heap_start = @intToPtr([*]u8, paging.KERNEL_VIRTUAL_BASE + 0x1000000);
    kernel_heap = heap.HeapAllocator.init(heap_start, 8 * 1024 * 1024); // 8MB initial heap

    // Enable paging
    paging.enablePaging();
}

fn stabilizeExecution() void {
    // Monitor and adjust system resources
    for (task_list) |task| {
        manageLifecycle(task.id);
        optimizeTask(task.id);
        adjustPulse(task.id);
    }
}

fn processEvents() void {
    // Handle pending events and interrupts
    while (event_queue.pop()) |event| {
        handleEvent(event);
    }
}

fn adjustSystemLoad() void {
    const current_load = calculateSystemLoad();
    if (current_load > 85) {
        // Implement load reduction strategies
        deferNonCriticalTasks();
    } else if (current_load < 20) {
        // Wake up sleeping tasks
        resumeIdleTasks();
    }
}
