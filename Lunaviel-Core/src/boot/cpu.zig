pub const GDT_ENTRY_COUNT = 3;

pub const GDTEntry = extern struct {
    limit_low: u16,
    base_low: u16,
    base_middle: u8,
    access: u8,
    granularity: u8,
    base_high: u8,
};

pub var gdt: [GDT_ENTRY_COUNT]GDTEntry = [_]GDTEntry{
    .{ .limit_low = 0, .base_low = 0, .base_middle = 0, .access = 0, .granularity = 0, .base_high = 0 }, // Null descriptor
    .{ .limit_low = 0xFFFF, .base_low = 0, .base_middle = 0, .access = 0x9A, .granularity = 0xCF, .base_high = 0 }, // Code segment
    .{ .limit_low = 0xFFFF, .base_low = 0, .base_middle = 0, .access = 0x92, .granularity = 0xCF, .base_high = 0 } // Data segment
};

pub fn loadGDT() void {
    asm volatile ("lgdt [%0]" :: "r"(&gdt));
}
