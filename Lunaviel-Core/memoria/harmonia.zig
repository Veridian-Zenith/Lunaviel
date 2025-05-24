const std = @import("std");
const log = @import("../seer/oracle.zig");
const aetherpage = @import("aetherpage.zig");

// Cache line size for Intel i3-1215U
const CACHE_LINE_SIZE: u32 = 64;

// Memory fence types
pub const FenceType = enum {
    Load,      // Load fence
    Store,     // Store fence
    Full,      // Full memory fence
    LoadStore, // Load + Store fence
};

// Cache control operations
pub const CacheOp = enum {
    Flush,          // Write back and invalidate
    FlushNoWB,      // Invalidate without writeback
    Prefetch,       // Prefetch data
    PrefetchNTA,    // Prefetch non-temporal
};

// Memory ordering modes
pub const MemoryOrder = enum {
    Relaxed,    // No ordering constraints
    Acquire,    // Acquire barrier
    Release,    // Release barrier
    AcqRel,     // Acquire + Release
    SeqCst,     // Sequential consistency
};

// Atomic operations support
pub fn atomic_fence(order: MemoryOrder) void {
    switch (order) {
        .Relaxed => {},
        .Acquire => asm volatile("lfence" ::: "memory"),
        .Release => asm volatile("sfence" ::: "memory"),
        .AcqRel, .SeqCst => asm volatile("mfence" ::: "memory"),
    }
}

// Memory fence operations
pub fn memory_fence(fence_type: FenceType) void {
    switch (fence_type) {
        .Load => asm volatile("lfence" ::: "memory"),
        .Store => asm volatile("sfence" ::: "memory"),
        .Full => asm volatile("mfence" ::: "memory"),
        .LoadStore => {
            asm volatile("lfence" ::: "memory");
            asm volatile("sfence" ::: "memory");
        },
    }
}

// Cache control operations
pub fn cache_op(op: CacheOp, addr: [*]u8, size: usize) void {
    var current = @ptrToInt(addr);
    const end = current + size;

    while (current < end) : (current += CACHE_LINE_SIZE) {
        switch (op) {
            .Flush => {
                asm volatile ("clflush (%[addr])"
                    :
                    : [addr] "r" (current)
                    : "memory"
                );
            },
            .FlushNoWB => {
                asm volatile ("clflushopt (%[addr])"
                    :
                    : [addr] "r" (current)
                    : "memory"
                );
            },
            .Prefetch => {
                asm volatile ("prefetcht0 (%[addr])"
                    :
                    : [addr] "r" (current)
                    : "memory"
                );
            },
            .PrefetchNTA => {
                asm volatile ("prefetchnta (%[addr])"
                    :
                    : [addr] "r" (current)
                    : "memory"
                );
            },
        }
    }
}

// Cache coherency management for multi-core operations
pub const CacheCoherencyManager = struct {
    const Self = @This();

    // Cache line status tracking
    const LineState = enum {
        Modified,
        Exclusive,
        Shared,
        Invalid,
    };

    // Cache line metadata
    const LineInfo = struct {
        state: LineState,
        core_id: u32,
        last_access: u64,
    };

    // Cache line tracking
    line_info: std.AutoHashMap(usize, LineInfo),
    stats: struct {
        hits: u64 = 0,
        misses: u64 = 0,
        invalidations: u64 = 0,
    },

    pub fn init(allocator: *std.mem.Allocator) !Self {
        return Self{
            .line_info = std.AutoHashMap(usize, LineInfo).init(allocator),
            .stats = .{},
        };
    }

    pub fn deinit(self: *Self) void {
        self.line_info.deinit();
    }

    // Track cache line access
    pub fn access_line(self: *Self, addr: usize, core_id: u32, is_write: bool) !void {
        const line_addr = addr & ~(@as(usize, CACHE_LINE_SIZE) - 1);

        if (self.line_info.get(line_addr)) |info| {
            // Cache hit
            self.stats.hits += 1;

            if (is_write) {
                // Handle write access
                switch (info.state) {
                    .Modified => {
                        // Already modified by this core
                        if (info.core_id != core_id) {
                            try self.invalidate_other_cores(line_addr);
                        }
                    },
                    .Exclusive => {
                        // Transition to Modified
                        try self.line_info.put(line_addr, .{
                            .state = .Modified,
                            .core_id = core_id,
                            .last_access = get_timestamp(),
                        });
                    },
                    .Shared => {
                        // Need exclusive access
                        try self.invalidate_other_cores(line_addr);
                        try self.line_info.put(line_addr, .{
                            .state = .Modified,
                            .core_id = core_id,
                            .last_access = get_timestamp(),
                        });
                    },
                    .Invalid => {
                        // Should not happen - treat as miss
                        self.stats.misses += 1;
                        try self.handle_miss(line_addr, core_id, is_write);
                    },
                }
            } else {
                // Handle read access
                switch (info.state) {
                    .Invalid => {
                        self.stats.misses += 1;
                        try self.handle_miss(line_addr, core_id, false);
                    },
                    else => {
                        // Update access time
                        var updated = info;
                        updated.last_access = get_timestamp();
                        try self.line_info.put(line_addr, updated);
                    },
                }
            }
        } else {
            // Cache miss
            self.stats.misses += 1;
            try self.handle_miss(line_addr, core_id, is_write);
        }
    }

    fn handle_miss(self: *Self, line_addr: usize, core_id: u32, is_write: bool) !void {
        const new_state: LineState = if (is_write) .Modified else .Shared;

        try self.line_info.put(line_addr, .{
            .state = new_state,
            .core_id = core_id,
            .last_access = get_timestamp(),
        });

        if (is_write) {
            try self.invalidate_other_cores(line_addr);
        }
    }

    fn invalidate_other_cores(self: *Self, line_addr: usize) !void {
        self.stats.invalidations += 1;

        // In a real system, this would send invalidation messages to other cores
        // For now, we just mark the line as invalid
        try self.line_info.put(line_addr, .{
            .state = .Invalid,
            .core_id = 0,
            .last_access = get_timestamp(),
        });

        // Ensure cache coherency
        cache_op(.Flush, @intToPtr([*]u8, line_addr), CACHE_LINE_SIZE);
    }

    // Get cache statistics
    pub fn get_stats(self: *const Self) struct {
        hit_rate: f64,
        miss_rate: f64,
        invalidations: u64,
    } {
        const total = self.stats.hits + self.stats.misses;
        const hit_rate = if (total > 0)
            @intToFloat(f64, self.stats.hits) / @intToFloat(f64, total)
        else
            0.0;

        return .{
            .hit_rate = hit_rate,
            .miss_rate = 1.0 - hit_rate,
            .invalidations = self.stats.invalidations,
        };
    }
};

// Get current timestamp
fn get_timestamp() u64 {
    var timestamp: u64 = undefined;
    asm volatile ("rdtsc"
        : [ret] "={eax}" (timestamp)
    );
    return timestamp;
}
