pub const IDT_ENTRY_COUNT = 256;

pub const IDTEntry = extern struct {
    offset_low: u16,
    selector: u16,
    zero: u8,
    type_attr: u8,
    offset_high: u16,
};

pub var idt_table: [IDT_ENTRY_COUNT]IDTEntry = undefined;

pub fn loadIDT() void {
    asm volatile ("lidt [%0]" :: "r"(&idt_table));
}
