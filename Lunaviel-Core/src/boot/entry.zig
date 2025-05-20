const std = @import("std");

pub fn _start() void {
    asm volatile ("cli");  // Disable interrupts
    asm volatile ("hlt");  // Halt until we move to kernel_main
}
