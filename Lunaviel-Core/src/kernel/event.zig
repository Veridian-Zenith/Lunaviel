pub fn listen(port: u16) u8 {
    var result: u8 = undefined;
    asm volatile ("inb %1, %0" : "=a"(result) : "dN"(port));
    return result;
}

pub fn whisper(port: u16, value: u8) void {
    asm volatile ("outb %1, %0" :: "dN"(port), "a"(value));
}
