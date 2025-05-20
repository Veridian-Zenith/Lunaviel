pub const PageSize = 4096;

pub var memory_pool: [256]u8 = undefined;

pub fn allocate(size: usize) ?[*]u8 {
    if (size > memory_pool.len) return null;
    return &memory_pool[0..size];
}

pub fn release(ptr: *u8) void {
    // Placeholder: Future memory reclamation logic
}
