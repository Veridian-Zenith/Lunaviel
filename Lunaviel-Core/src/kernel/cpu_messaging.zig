pub fn pulseCPU(command: u8) void {
    asm volatile (
        "mov %0, %%eax\n"
        "int 0x90"
        :: "r"(command)
    );
}
