const std = @import("std");
const event_system = @import("event_system.zig");
const process = @import("../process/execute.zig");
const memory = @import("../mm/virtual_memory.zig");
const driver_registry = @import("../drivers/driver_registry.zig");

pub const SyscallError = error{
    InvalidCall,
    InvalidArgument,
    PermissionDenied,
    ResourceNotFound,
    OutOfMemory,
    DeviceError,
    DriverNotFound,
    DriverBusy,
    ResourceUnavailable,
};

pub const SyscallResult = union(enum) {
    success: usize,
    error: SyscallError,
};

pub const SyscallHandler = fn (args: []const usize) SyscallResult;

// Core system calls
pub const SYS_EXIT = 0x01;
pub const SYS_READ = 0x02;
pub const SYS_WRITE = 0x03;
pub const SYS_OPEN = 0x04;
pub const SYS_CLOSE = 0x05;
pub const SYS_FORK = 0x06;
pub const SYS_EXEC = 0x07;
pub const SYS_MMAP = 0x08;
pub const SYS_MUNMAP = 0x09;
pub const SYS_PULSE = 0x0A;
pub const SYS_HARMONIZE = 0x0B;
pub const SYS_RESONATE = 0x0C;

// Driver-specific system calls
pub const SYS_DRIVER_QUERY = 0x20;
pub const SYS_DRIVER_CONTROL = 0x21;
pub const SYS_DRIVER_IO = 0x22;
pub const SYS_DRIVER_STATUS = 0x23;

pub const syscall_table = [_]?SyscallHandler{
    sys_exit,          // 0x01
    sys_read,          // 0x02
    sys_write,         // 0x03
    sys_open,          // 0x04
    sys_close,         // 0x05
    sys_fork,          // 0x06
    sys_exec,          // 0x07
    sys_mmap,          // 0x08
    sys_munmap,        // 0x09
    sys_pulse,         // 0x0A
    sys_harmonize,     // 0x0B
    sys_resonate,      // 0x0C
    null,              // 0x0D
    null,              // 0x0E
    null,              // 0x0F
    null,              // 0x10
    null,              // 0x11
    null,              // 0x12
    null,              // 0x13
    null,              // 0x14
    null,              // 0x15
    null,              // 0x16
    null,              // 0x17
    null,              // 0x18
    null,              // 0x19
    null,              // 0x1A
    null,              // 0x1B
    null,              // 0x1C
    null,              // 0x1D
    null,              // 0x1E
    null,              // 0x1F
    sys_driver_query,  // 0x20
    sys_driver_control,// 0x21
    sys_driver_io,     // 0x22
    sys_driver_status, // 0x23
};

// Existing syscall implementations...

fn sys_driver_query(args: []const usize) SyscallResult {
    const driver_type = args[0];
    const query_flags = args[1];

    const core = @import("main.zig").getExecutionCore();
    const registry = core.driver_registry;

    if (registry.findDriverByType(@intToEnum(driver.DriverType, driver_type))) |drv| {
        // Pack driver info into result
        const info = registry.getDriverInfo(drv.id).?;
        const result = (@as(u64, info.id) << 48) |
                      (@as(u64, @enumToInt(info.type)) << 40) |
                      (@as(u64, info.version) << 32) |
                      (@as(u64, @boolToInt(drv.capabilities.async_io)) << 31) |
                      (@as(u64, @boolToInt(drv.capabilities.dma_support)) << 30) |
                      (@as(u64, @floatToInt(u8, drv.flow.resonance * 100.0)));
        return SyscallResult{ .success = result };
    }

    return SyscallResult{ .error = SyscallError.DriverNotFound };
}

fn sys_driver_control(args: []const usize) SyscallResult {
    const driver_id = @intCast(u16, args[0]);
    const command = args[1];
    const param = args[2];

    const core = @import("main.zig").getExecutionCore();
    const registry = core.driver_registry;

    if (registry.getDriver(driver_id)) |drv| {
        switch (command) {
            0x01 => { // Set power state
                if (drv.capabilities.power_management) {
                    // Power management implementation
                    return SyscallResult{ .success = 0 };
                }
                return SyscallResult{ .error = SyscallError.InvalidArgument };
            },
            0x02 => { // Configure DMA
                if (drv.capabilities.dma_support) {
                    // DMA configuration implementation
                    return SyscallResult{ .success = 0 };
                }
                return SyscallResult{ .error = SyscallError.InvalidArgument };
            },
            0x03 => { // Set resonance target
                drv.flow.resonance = @intToFloat(f32, param) / 100.0;
                return SyscallResult{ .success = 0 };
            },
            else => return SyscallResult{ .error = SyscallError.InvalidArgument },
        }
    }

    return SyscallResult{ .error = SyscallError.DriverNotFound };
}

fn sys_driver_io(args: []const usize) SyscallResult {
    const driver_id = @intCast(u16, args[0]);
    const buffer_ptr = args[1];
    const buffer_len = args[2];
    const flags = args[3];

    const core = @import("main.zig").getExecutionCore();
    const registry = core.driver_registry;

    if (registry.getDriver(driver_id)) |drv| {
        if (drv.state == .Error or drv.state == .Suspended) {
            return SyscallResult{ .error = SyscallError.ResourceUnavailable };
        }

        const buffer = @intToPtr([*]u8, buffer_ptr)[0..buffer_len];
        drv.submitIO(buffer, 0, .Normal) catch |err| {
            return SyscallResult{ .error = SyscallError.DeviceError };
        };

        if (flags & 1 == 0) { // Synchronous operation
            // Wait for completion
            while (!drv.io_queue.isRequestComplete()) {
                asm volatile ("pause");
            }
        }

        return SyscallResult{ .success = buffer_len };
    }

    return SyscallResult{ .error = SyscallError.DriverNotFound };
}

fn sys_driver_status(args: []const usize) SyscallResult {
    const driver_id = @intCast(u16, args[0]);

    const core = @import("main.zig").getExecutionCore();
    const registry = core.driver_registry;

    if (registry.getDriver(driver_id)) |drv| {
        const status = (@as(u64, @enumToInt(drv.state)) << 56) |
                      (@as(u64, @floatToInt(u8, drv.flow.resonance * 100.0)) << 48) |
                      (@as(u64, @floatToInt(u8, drv.flow.error_rate * 100.0)) << 40) |
                      (@as(u64, drv.io_queue.pending_requests) << 32) |
                      (@as(u64, @floatToInt(u32, drv.flow.bandwidth)));
        return SyscallResult{ .success = status };
    }

    return SyscallResult{ .error = SyscallError.DriverNotFound };
}
