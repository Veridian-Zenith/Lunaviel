const std = @import("std");
const Task = @import("taskweave.zig").Task;
const log = @import("../seer/oracle.zig").log;

// Thread states
pub const ThreadState = enum {
    New,
    Running,
    Ready,
    Blocked,
    Terminated,
};

// Thread priority levels
pub const ThreadPriority = enum(u8) {
    Critical = 0,
    High = 1,
    Normal = 2,
    Low = 3,
    Background = 4,
};

// Core types for Intel hybrid architecture
pub const CoreType = enum {
    Performance,  // P-cores
    Efficient,   // E-cores
    Any,         // No preference
};

// Thread local storage structure
const TLS = struct {
    self: *Thread,
    errno: i32,
    stack_canary: u64,
    // Add more TLS variables as needed
};

// Thread context structure
const ThreadContext = packed struct {
    // General purpose registers
    rax: u64 = 0,
    rbx: u64 = 0,
    rcx: u64 = 0,
    rdx: u64 = 0,
    rsi: u64 = 0,
    rdi: u64 = 0,
    rbp: u64 = 0,
    r8:  u64 = 0,
    r9:  u64 = 0,
    r10: u64 = 0,
    r11: u64 = 0,
    r12: u64 = 0,
    r13: u64 = 0,
    r14: u64 = 0,
    r15: u64 = 0,

    // Special registers
    rip: u64 = 0,        // Instruction pointer
    rsp: u64 = 0,        // Stack pointer
    rflags: u64 = 0x202, // CPU flags (IF bit set)

    // Segment registers
    cs: u16 = 0x08,      // Code segment
    ds: u16 = 0x10,      // Data segment
    es: u16 = 0x10,
    fs: u16 = 0x10,
    gs: u16 = 0x10,
    ss: u16 = 0x10,

    // Vector registers state
    xmm_state: [512]u8 align(16) = [_]u8{0} ** 512,  // Space for XMM0-XMM15
    ymm_state: [256]u8 align(32) = [_]u8{0} ** 256,  // Space for YMM registers
};

pub const Thread = struct {
    id: u64,
    name: []const u8,
    state: ThreadState,
    priority: ThreadPriority,
    core_preference: CoreType,
    context: ThreadContext,
    stack: []align(16) u8,
    tls: *TLS,
    task: ?*Task,
    next: ?*Thread,
    prev: ?*Thread,

    // Thread statistics
    cpu_time: u64,
    context_switches: u64,
    priority_boosts: u32,
    cache_misses: u64,

    pub fn init(allocator: *std.mem.Allocator, name: []const u8, stack_size: usize, priority: ThreadPriority) !*Thread {
        const stack = try allocator.alignedAlloc(u8, 16, stack_size);
        const tls = try allocator.create(TLS);

        var thread = try allocator.create(Thread);
        thread.* = Thread{
            .id = generateThreadId(),
            .name = name,
            .state = .New,
            .priority = priority,
            .core_preference = .Any,
            .context = ThreadContext{},
            .stack = stack,
            .tls = tls,
            .task = null,
            .next = null,
            .prev = null,
            .cpu_time = 0,
            .context_switches = 0,
            .priority_boosts = 0,
            .cache_misses = 0,
        };

        // Set up initial stack
        const stack_top = @ptrToInt(stack.ptr) + stack.len;
        thread.context.rsp = stack_top;
        thread.context.rbp = stack_top;

        // Initialize TLS
        thread.tls.* = TLS{
            .self = thread,
            .errno = 0,
            .stack_canary = generateCanary(),
        };

        return thread;
    }

    pub fn deinit(self: *Thread, allocator: *std.mem.Allocator) void {
        allocator.free(self.stack);
        allocator.destroy(self.tls);
        allocator.destroy(self);
    }

    pub fn switch_to(self: *Thread, next: *Thread) void {
        if (self.state == .Running) {
            self.state = .Ready;
        }
        next.state = .Running;
        next.context_switches += 1;

        self.save_context();
        self.save_vector_state();

        // Switch FS register to point to next thread's TLS
        set_fs_base(@ptrToInt(next.tls));

        next.restore_vector_state();
        next.restore_context();
    }

    fn save_context(self: *Thread) void {
        asm volatile (
            \\mov [%[ctx] + 0x00], rax
            \\mov [%[ctx] + 0x08], rbx
            \\mov [%[ctx] + 0x10], rcx
            \\mov [%[ctx] + 0x18], rdx
            \\mov [%[ctx] + 0x20], rsi
            \\mov [%[ctx] + 0x28], rdi
            \\mov [%[ctx] + 0x30], rbp
            \\mov [%[ctx] + 0x38], r8
            \\mov [%[ctx] + 0x40], r9
            \\mov [%[ctx] + 0x48], r10
            \\mov [%[ctx] + 0x50], r11
            \\mov [%[ctx] + 0x58], r12
            \\mov [%[ctx] + 0x60], r13
            \\mov [%[ctx] + 0x68], r14
            \\mov [%[ctx] + 0x70], r15
            \\lea rax, [rip + 2f]
            \\mov [%[ctx] + 0x78], rax  # Save next instruction pointer
            \\mov [%[ctx] + 0x80], rsp
            \\pushfq
            \\pop rax
            \\mov [%[ctx] + 0x88], rax
            \\jmp 1f
            \\2:
            \\ret
            \\1:
            :
            : [ctx] "r" (&self.context)
            : "memory", "rax"
        );
    }

    fn restore_context(self: *Thread) void {
        asm volatile (
            \\mov rax, [%[ctx] + 0x88]  # Restore RFLAGS
            \\push rax
            \\popfq
            \\mov rsp, [%[ctx] + 0x80]  # Restore RSP
            \\mov rax, [%[ctx] + 0x00]
            \\mov rbx, [%[ctx] + 0x08]
            \\mov rcx, [%[ctx] + 0x10]
            \\mov rdx, [%[ctx] + 0x18]
            \\mov rsi, [%[ctx] + 0x20]
            \\mov rdi, [%[ctx] + 0x28]
            \\mov rbp, [%[ctx] + 0x30]
            \\mov r8,  [%[ctx] + 0x38]
            \\mov r9,  [%[ctx] + 0x40]
            \\mov r10, [%[ctx] + 0x48]
            \\mov r11, [%[ctx] + 0x50]
            \\mov r12, [%[ctx] + 0x58]
            \\mov r13, [%[ctx] + 0x60]
            \\mov r14, [%[ctx] + 0x68]
            \\mov r15, [%[ctx] + 0x70]
            \\jmp [%[ctx] + 0x78]  # Jump to saved instruction pointer
            :
            : [ctx] "r" (&self.context)
            : "memory"
        );
    }

    fn save_vector_state(self: *Thread) void {
        // Save XMM registers
        asm volatile (
            \\movdqu [%[state] + 0x00], xmm0
            \\movdqu [%[state] + 0x10], xmm1
            \\movdqu [%[state] + 0x20], xmm2
            \\movdqu [%[state] + 0x30], xmm3
            \\movdqu [%[state] + 0x40], xmm4
            \\movdqu [%[state] + 0x50], xmm5
            \\movdqu [%[state] + 0x60], xmm6
            \\movdqu [%[state] + 0x70], xmm7
            \\movdqu [%[state] + 0x80], xmm8
            \\movdqu [%[state] + 0x90], xmm9
            \\movdqu [%[state] + 0xa0], xmm10
            \\movdqu [%[state] + 0xb0], xmm11
            \\movdqu [%[state] + 0xc0], xmm12
            \\movdqu [%[state] + 0xd0], xmm13
            \\movdqu [%[state] + 0xe0], xmm14
            \\movdqu [%[state] + 0xf0], xmm15
            :
            : [state] "r" (&self.context.xmm_state)
            : "memory"
        );

        // Save YMM high bits if AVX is available
        if (cpu_has_avx()) {
            asm volatile (
                \\vextractf128 [%[state] + 0x00], ymm0, 1
                \\vextractf128 [%[state] + 0x10], ymm1, 1
                \\vextractf128 [%[state] + 0x20], ymm2, 1
                \\vextractf128 [%[state] + 0x30], ymm3, 1
                \\vextractf128 [%[state] + 0x40], ymm4, 1
                \\vextractf128 [%[state] + 0x50], ymm5, 1
                \\vextractf128 [%[state] + 0x60], ymm6, 1
                \\vextractf128 [%[state] + 0x70], ymm7, 1
                :
                : [state] "r" (&self.context.ymm_state)
                : "memory"
            );
        }
    }

    fn restore_vector_state(self: *Thread) void {
        // Restore XMM registers
        asm volatile (
            \\movdqu xmm0,  [%[state] + 0x00]
            \\movdqu xmm1,  [%[state] + 0x10]
            \\movdqu xmm2,  [%[state] + 0x20]
            \\movdqu xmm3,  [%[state] + 0x30]
            \\movdqu xmm4,  [%[state] + 0x40]
            \\movdqu xmm5,  [%[state] + 0x50]
            \\movdqu xmm6,  [%[state] + 0x60]
            \\movdqu xmm7,  [%[state] + 0x70]
            \\movdqu xmm8,  [%[state] + 0x80]
            \\movdqu xmm9,  [%[state] + 0x90]
            \\movdqu xmm10, [%[state] + 0xa0]
            \\movdqu xmm11, [%[state] + 0xb0]
            \\movdqu xmm12, [%[state] + 0xc0]
            \\movdqu xmm13, [%[state] + 0xd0]
            \\movdqu xmm14, [%[state] + 0xe0]
            \\movdqu xmm15, [%[state] + 0xf0]
            :
            : [state] "r" (&self.context.xmm_state)
            : "xmm0", "xmm1", "xmm2", "xmm3", "xmm4", "xmm5", "xmm6", "xmm7",
              "xmm8", "xmm9", "xmm10", "xmm11", "xmm12", "xmm13", "xmm14", "xmm15"
        );

        // Restore YMM high bits if AVX is available
        if (cpu_has_avx()) {
            asm volatile (
                \\vinsertf128 ymm0, ymm0, [%[state] + 0x00], 1
                \\vinsertf128 ymm1, ymm1, [%[state] + 0x10], 1
                \\vinsertf128 ymm2, ymm2, [%[state] + 0x20], 1
                \\vinsertf128 ymm3, ymm3, [%[state] + 0x30], 1
                \\vinsertf128 ymm4, ymm4, [%[state] + 0x40], 1
                \\vinsertf128 ymm5, ymm5, [%[state] + 0x50], 1
                \\vinsertf128 ymm6, ymm6, [%[state] + 0x60], 1
                \\vinsertf128 ymm7, ymm7, [%[state] + 0x70], 1
                :
                : [state] "r" (&self.context.ymm_state)
                : "ymm0", "ymm1", "ymm2", "ymm3", "ymm4", "ymm5", "ymm6", "ymm7"
            );
        }
    }
};

// Helper functions
fn generateThreadId() u64 {
    const timestamp = @intCast(u64, std.time.milliTimestamp());
    const random = @intCast(u16, std.crypto.random.int(u16));
    return (timestamp << 16) | random;
}

fn generateCanary() u64 {
    return std.crypto.random.int(u64);
}

fn set_fs_base(addr: u64) void {
    const MSR_FS_BASE = 0xC0000100;
    asm volatile ("wrmsr"
        :
        : [addr] "{edx}" (@intCast(u32, addr >> 32)),
          [addr_low] "{eax}" (@intCast(u32, addr & 0xFFFFFFFF)),
          [msr] "{ecx}" (MSR_FS_BASE)
    );
}

fn cpu_has_avx() bool {
    var eax: u32 = undefined;
    var ebx: u32 = undefined;
    var ecx: u32 = undefined;
    var edx: u32 = undefined;

    // Check CPUID.1:ECX.AVX[bit 28]
    asm volatile ("cpuid"
        : [eax] "={eax}" (eax),
          [ebx] "={ebx}" (ebx),
          [ecx] "={ecx}" (ecx),
          [edx] "={edx}" (edx)
        : [leaf] "{eax}" (1)
    );

    return (ecx & (1 << 28)) != 0;
}
