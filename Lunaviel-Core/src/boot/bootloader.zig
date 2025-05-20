const std = @import("std");
const memory = @import("../memory/mem.zig");
const interrupts = @import("../kernel/interrupts.zig");
const kernel = @import("../kernel/main.zig");

pub fn bootLunaviel() void {
    // Basic CPU initialization
    asm volatile ("cli");  // Disable interrupts

    // Set up core system tables
    loadGDT();            // Load Global Descriptor Table
    loadIDT();            // Load Interrupt Descriptor Table

    // Initialize core systems
    memory.init();        // Initialize memory management
    interrupts.init();    // Initialize interrupt handling

    // Enable interrupts and transfer to kernel
    asm volatile ("sti");
    kernel.kernel_main(); // Transition to Lunaviel's core
}ootLunaviel() void {
    asm volatile ("cli");  // Disable interrupts
    loadGDT();             // Load Global Descriptor Table
    loadIDT();             // Load Interrupt Descriptor Table
    asm volatile ("sti");  // Enable interrupts

    kernel_main();         // Transition to Lunaviel’s core
}
