const std = @import("std");
const event_system = @import("event_system.zig");
const process = @import("../process/execute.zig");
const memory = @import("../mm/virtual_memory.zig");

pub const SyscallError = error{
    InvalidCall,
    InvalidArgument,
    PermissionDenied,
    ResourceNotFound,
    OutOfMemory,
    DeviceError,
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
pub const SYS_PULSE = 0x0A;  // Lunaviel-specific: Interact with system pulse
pub const SYS_HARMONIZE = 0x0B;  // Lunaviel-specific: Adjust task harmony
pub const SYS_RESONATE = 0x0C;  // Lunaviel-specific: Control resource resonance

pub const syscall_table = [_]?SyscallHandler{
    sys_exit,    // 0x01
    sys_read,    // 0x02
    sys_write,   // 0x03
    sys_open,    // 0x04
    sys_close,   // 0x05
    sys_fork,    // 0x06
    sys_exec,    // 0x07
    sys_mmap,    // 0x08
    sys_munmap,  // 0x09
    sys_pulse,   // 0x0A
    sys_harmonize, // 0x0B
    sys_resonate,  // 0x0C
};

fn sys_exit(args: []const usize) SyscallResult {
    const status = args[0];
    process.exit(status);
    return SyscallResult{ .success = 0 };
}

fn sys_read(args: []const usize) SyscallResult {
    const fd = args[0];
    const buf = @intToPtr([*]u8, args[1]);
    const count = args[2];

    // TODO: Implement actual file descriptor read
    return SyscallResult{ .error = SyscallError.InvalidCall };
}

fn sys_write(args: []const usize) SyscallResult {
    const fd = args[0];
    const buf = @intToPtr([*]const u8, args[1]);
    const count = args[2];

    // TODO: Implement actual file descriptor write
    return SyscallResult{ .error = SyscallError.InvalidCall };
}

fn sys_open(args: []const usize) SyscallResult {
    const path = @intToPtr([*:0]const u8, args[0]);
    const flags = args[1];
    const mode = args[2];

    // TODO: Implement file open
    return SyscallResult{ .error = SyscallError.InvalidCall };
}

fn sys_close(args: []const usize) SyscallResult {
    const fd = args[0];

    // TODO: Implement file close
    return SyscallResult{ .error = SyscallError.InvalidCall };
}

fn sys_fork(args: []const usize) SyscallResult {
    // TODO: Implement process forking
    return SyscallResult{ .error = SyscallError.InvalidCall };
}

fn sys_exec(args: []const usize) SyscallResult {
    const path = @intToPtr([*:0]const u8, args[0]);
    const argv = @intToPtr([*][*:0]const u8, args[1]);

    // TODO: Implement process execution
    return SyscallResult{ .error = SyscallError.InvalidCall };
}

fn sys_mmap(args: []const usize) SyscallResult {
    const addr = args[0];
    const length = args[1];
    const prot = args[2];
    const flags = args[3];

    // TODO: Implement memory mapping
    return SyscallResult{ .error = SyscallError.InvalidCall };
}

fn sys_munmap(args: []const usize) SyscallResult {
    const addr = args[0];
    const length = args[1];

    // TODO: Implement memory unmapping
    return SyscallResult{ .error = SyscallError.InvalidCall };
}

fn sys_pulse(args: []const usize) SyscallResult {
    const task_id = args[0];
    const amplitude = args[1];

    // Get the global execution core instance
    const core = @import("main.zig").getExecutionCore();
    return core.handleTaskPulse(task_id, amplitude);
}

fn sys_harmonize(args: []const usize) SyscallResult {
    const task_id = args[0];
    const harmony_flags = args[1];

    const core = @import("main.zig").getExecutionCore();
    return core.handleTaskHarmonize(task_id, harmony_flags);
}

fn sys_resonate(args: []const usize) SyscallResult {
    const resource_id = args[0];
    const resonance_level = args[1];

    const core = @import("main.zig").getExecutionCore();
    return core.handleResourceResonate(resource_id, resonance_level);
}
