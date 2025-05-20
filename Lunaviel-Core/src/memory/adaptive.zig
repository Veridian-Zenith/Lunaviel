pub fn allocateMemory(size: usize) ?[*]u8 {
    if (system_load > 80) return null; // Prevent excessive strain

    var block: ?[*]u8 = allocate(size);
    return block;
}
