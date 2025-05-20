pub fn handleException(code: u8) void {
    switch (code) {
        0 => pulseCPU(0x01), // Recover gracefully
        1 => waitCycles(5000), // Soft reset
        else => whisper(0x60, 0xFF), // Fallback correction
    }
}
