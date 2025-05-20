const std = @import("std");

pub fn _start() void {
    asm volatile ("cli");  // Disable interrupts
    bootLunaviel();       // Initialize core systems
}
