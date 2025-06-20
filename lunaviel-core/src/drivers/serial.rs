//! Minimal serial driver for kernel output (e.g., for sys_write)

// TODO: Implement serial port initialization and output for x86_64 (e.g., COM1 at 0x3F8)

pub fn serial_write_byte(byte: u8) {
    // Write byte to serial port (e.g., using outb on port 0x3F8)
    // This is a stub for now
}

pub fn serial_write(buf: &[u8]) {
    for &b in buf {
        serial_write_byte(b);
    }
}
