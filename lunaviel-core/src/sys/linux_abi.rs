//! Minimal Linux-compatible syscall ABI layer (inspired by asterinas)
//! Provides syscall numbers, dispatch, and stubs for initial syscalls.

#![allow(dead_code)]

// Linux syscall numbers (partial, extend as needed)
pub const SYS_READ: usize = 0;
pub const SYS_WRITE: usize = 1;
pub const SYS_OPEN: usize = 2;
pub const SYS_CLOSE: usize = 3;
pub const SYS_EXIT: usize = 60;
pub const SYS_FSTAT: usize = 5;
pub const SYS_GETPID: usize = 39;
// ... add more as needed

/// Syscall dispatch entry point
/// Arguments: syscall number and up to 6 arguments (as per Linux x86_64 ABI)
pub fn syscall_dispatch(num: usize, arg1: usize, arg2: usize, arg3: usize, arg4: usize, arg5: usize, arg6: usize) -> usize {
    match num {
        SYS_WRITE => sys_write(arg1, arg2, arg3),
        SYS_READ => sys_read(arg1, arg2, arg3),
        SYS_EXIT => sys_exit(arg1),
        // ... add more syscalls here
        _ => usize::MAX, // ENOSYS
    }
}

// --- Syscall stubs ---

fn sys_write(fd: usize, buf: usize, count: usize) -> usize {
    // TODO: Implement write syscall (e.g., to serial, framebuffer, etc.)
    0
}

fn sys_read(fd: usize, buf: usize, count: usize) -> usize {
    // TODO: Implement read syscall
    0
}

fn sys_exit(status: usize) -> usize {
    // TODO: Implement exit syscall (terminate process)
    loop {}
}
