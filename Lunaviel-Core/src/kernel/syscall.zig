const std = @import("std");
const syscall_table = @import("syscall_table.zig");
const idt = @import("idt.zig");
const event_system = @import("event_system.zig");

/// Initialize system call handling
pub fn init() void {
    // Set up system call interrupt handlers
    idt.setHandler(0x80, handleSyscall);
    idt.setHandler(0x81, handleExtendedSyscall);
}

/// Standard system call handler for int 0x80
fn handleSyscall(frame: *idt.InterruptFrame) void {
    const syscall_id = frame.eax;
    const arg1 = frame.ebx;
    const arg2 = frame.ecx;

    const args = [_]usize{ arg1, arg2 };

    if (syscall_id >= syscall_table.syscall_table.len) {
        frame.eax = @enumToInt(syscall_table.SyscallError.InvalidCall);
        return;
    }

    const handler = syscall_table.syscall_table[syscall_id] orelse {
        frame.eax = @enumToInt(syscall_table.SyscallError.InvalidCall);
        return;
    };

    const result = handler(&args);
    switch (result) {
        .success => |value| frame.eax = value,
        .error => |err| frame.eax = @enumToInt(err),
    }
}

/// Extended system call handler for int 0x81 (supports additional argument)
fn handleExtendedSyscall(frame: *idt.InterruptFrame) void {
    const syscall_id = frame.eax;
    const arg1 = frame.ebx;
    const arg2 = frame.ecx;
    const arg3 = frame.edx;

    const args = [_]usize{ arg1, arg2, arg3 };

    if (syscall_id >= syscall_table.syscall_table.len) {
        frame.eax = @enumToInt(syscall_table.SyscallError.InvalidCall);
        return;
    }

    const handler = syscall_table.syscall_table[syscall_id] orelse {
        frame.eax = @enumToInt(syscall_table.SyscallError.InvalidCall);
        return;
    };

    const result = handler(&args);
    switch (result) {
        .success => |value| frame.eax = value,
        .error => |err| frame.eax = @enumToInt(err),
    }
}

/// User-space system call invocation
pub fn invoke_syscall(syscall_id: u8, arg1: usize, arg2: usize) usize {
    var result: usize = undefined;
    asm volatile (
        "int 0x80"
        : "=a"(result)
        : "a"(syscall_id), "b"(arg1), "c"(arg2)
    );
    return result;
}

/// User-space extended system call invocation
pub fn invoke_extended_syscall(call_id: u8, arg1: usize, arg2: usize, arg3: usize) usize {
    var result: usize = undefined;
    asm volatile (
        "int 0x81"
        : "=a"(result)
        : "a"(call_id), "b"(arg1), "c"(arg2), "d"(arg3)
    );
    return result;
}
