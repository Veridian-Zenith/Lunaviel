pub fn bootLunaviel() void {
    asm volatile ("cli");  // Disable interrupts
    loadGDT();             // Load Global Descriptor Table
    loadIDT();             // Load Interrupt Descriptor Table
    asm volatile ("sti");  // Enable interrupts

    kernel_main();         // Transition to Lunaviel’s core
}
