// aether/etherial.zig
const IDTEntry = packed struct {
    offset_low: u16,
    segment_selector: u16,
    ist: u8,        // 3 bits used, rest reserved
    flags: u8,
    offset_mid: u16,
    offset_high: u32,
    reserved: u32,
};

const IDTR = packed struct {
    size: u16,
    offset: u64,
};

const NUM_INTERRUPTS = 256;
var idt_entries: [NUM_INTERRUPTS]IDTEntry = undefined;
var idtr: IDTR = undefined;

fn create_idt_entry(handler: u64, segment: u16, flags: u8) IDTEntry {
    return IDTEntry{
        .offset_low = @truncate(u16, handler),
        .segment_selector = segment,
        .ist = 0,
        .flags = flags,
        .offset_mid = @truncate(u16, handler >> 16),
        .offset_high = @truncate(u32, handler >> 32),
        .reserved = 0,
    };
}

fn register_interrupt(index: u8, handler: u64) void {
    idt_entries[index] = create_idt_entry(
        handler,
        0x08,  // Code segment
        0x8E,  // Present, Ring 0, Interrupt Gate
    );
}

export fn isr_handler() void {
    asm volatile (
        \\ push %%rax
        \\ push %%rcx
        \\ push %%rdx
        \\ push %%rbx
        \\ push %%rbp
        \\ push %%rsi
        \\ push %%rdi
    );

    // Handle interrupt here

    asm volatile (
        \\ pop %%rdi
        \\ pop %%rsi
        \\ pop %%rbp
        \\ pop %%rbx
        \\ pop %%rdx
        \\ pop %%rcx
        \\ pop %%rax
        \\ iretq
    );
}

// Handlers for different interrupts
extern fn keyboard_handler() void;
extern fn timer_handler() void;
extern fn syscall_handler() void;

pub fn init() void {
    // Setup IDT entries
    for (idt_entries) |*entry, i| {
        entry.* = create_idt_entry(0, 0x08, 0x8E);
    }

    // Register essential interrupt handlers
    register_interrupt(0x20, @ptrToInt(timer_handler));     // Timer
    register_interrupt(0x21, @ptrToInt(keyboard_handler));  // Keyboard
    register_interrupt(0x80, @ptrToInt(syscall_handler));   // Syscall

    // Setup IDTR
    idtr = IDTR{
        .size = @sizeOf(@TypeOf(idt_entries)) - 1,
        .offset = @ptrToInt(&idt_entries),
    };

    // Load IDT
    asm volatile (
        \\ lidt (%[idtr])
        :
        : [idtr] "r" (&idtr)
    );

    // Enable interrupts
    asm volatile ("sti");
}
