//! Linux-compatible syscall table and dispatch macros (inspired by asterinas)

// Macro to define syscall numbers and dispatch function
#[macro_export]
macro_rules! define_syscalls {
    (
        $( $name:ident = $num:literal => $handler:ident ( $($arg:ident),* ) ),* $(,)?
    ) => {
        $(pub const $name: usize = $num;)*

        pub fn syscall_dispatch(num: usize, args: [usize; 6]) -> isize {
            match num {
                $(
                    $num => $handler($(args[$crate::syscalls::syscall_table::arg_index!($arg)]),*),
                )*
                _ => -38, // ENOSYS
            }
        }
    };
}

#[macro_export]
macro_rules! arg_index {
    (a1) => { 0 };
    (a2) => { 1 };
    (a3) => { 2 };
    (a4) => { 3 };
    (a5) => { 4 };
    (a6) => { 5 };
}

use crate::drivers::serial;

// Example syscall handler stubs
pub fn sys_read(fd: usize, buf: usize, count: usize) -> isize {
    // TODO: Implement read syscall
    0
}

pub fn sys_write(fd: usize, buf: usize, count: usize) -> isize {
    // For now, only support fd=1 (stdout) and fd=2 (stderr)
    if fd == 1 || fd == 2 {
        // Safety: userland provides the pointer, kernel must validate in production
        let slice = unsafe { core::slice::from_raw_parts(buf as *const u8, count) };
        serial::serial_write(slice);
        count as isize
    } else {
        -1 // EBADF
    }
}

pub fn sys_open(path: usize, flags: usize, mode: usize) -> isize {
    // TODO: Implement open syscall
    -1 // ENOENT
}

pub fn sys_close(fd: usize) -> isize {
    // TODO: Implement close syscall
    0
}

pub fn sys_exit(status: usize) -> isize {
    // TODO: Implement exit syscall
    loop {}
}

// Define the syscall table (expand as needed)
define_syscalls! {
    SYS_READ = 0 => sys_read(a1, a2, a3),
    SYS_WRITE = 1 => sys_write(a1, a2, a3),
    SYS_OPEN = 2 => sys_open(a1, a2, a3),
    SYS_CLOSE = 3 => sys_close(a1),
    SYS_EXIT = 60 => sys_exit(a1)
}
