//! x86_64 syscall/trap handler for Linux ABI syscalls
//! Wires CPU syscall/trap to the kernel syscall dispatcher

use crate::syscalls::syscall_dispatch;

/// Called from the CPU trap/interrupt handler for syscalls
/// Arguments: syscall number and up to 6 arguments (as per Linux x86_64 ABI)
pub fn handle_syscall(num: usize, args: [usize; 6]) -> isize {
    syscall_dispatch(num, args)
}

// TODO: Wire this into your IDT/trap table for INT 0x80 or SYSCALL
// Example (pseudo-code):
// fn int_0x80_handler(cpu_state: &mut CpuState) {
//     let num = cpu_state.rax;
//     let args = [cpu_state.rdi, cpu_state.rsi, cpu_state.rdx, cpu_state.r10, cpu_state.r8, cpu_state.r9];
//     let ret = handle_syscall(num, args);
//     cpu_state.rax = ret as usize;
// }
