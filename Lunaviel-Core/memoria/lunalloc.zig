const std = @import("std");
const aetherpage = @import("aetherpage.zig");
const CoreType = aetherpage.CoreType;

// Memory block header structure
const BlockHeader = packed struct {
    size: usize,            // Size of the block including header
    is_free: bool,         // Whether the block is free
    prev: ?*BlockHeader,   // Previous block in the list
    next: ?*BlockHeader,   // Next block in the list
    core_affinity: CoreType, // Preferred core type
    cache_hint: u8,        // Cache placement hint
    access_count: u32,     // Block access counter
};

// Cache-specific allocator pools
const CachePool = struct {
    l1_blocks: ?*BlockHeader,  // Blocks fitting in L1 cache
    l2_blocks: ?*BlockHeader,  // Blocks fitting in L2 cache
    l3_blocks: ?*BlockHeader,  // Blocks fitting in L3 cache
    uncached_blocks: ?*BlockHeader, // Blocks that don't need caching
};

// Heap configuration
const HEAP_START: usize = 0x200000;    // 2MB
const HEAP_INITIAL_SIZE: usize = 4 * 1024 * 1024;  // 4MB
const MIN_BLOCK_SIZE: usize = 32;      // Minimum block size including header

// Cache sizes from aetherpage.zig
const L1_CACHE_SIZE: usize = 80 * 1024;     // 80KB
const L2_CACHE_SIZE: usize = 1536 * 1024;   // 1.5MB
const L3_CACHE_SIZE: usize = 10 * 1024 * 1024; // 10MB
const CACHE_LINE_SIZE: usize = 64;    // 64 bytes

// Heap state
var heap_initialized: bool = false;
var heap_start: *BlockHeader = undefined;
var heap_end: *BlockHeader = undefined;
var cache_pools: CachePool = undefined;

// Statistics
var stats = struct {
    total_allocations: usize = 0,
    total_frees: usize = 0,
    current_usage: usize = 0,
    peak_usage: usize = 0,
    cache_hits: usize = 0,
    cache_misses: usize = 0,
}{};

// Initialize the heap
pub fn init() !void {
    if (heap_initialized) return;

    // Map initial heap pages
    var i: usize = 0;
    while (i < HEAP_INITIAL_SIZE) : (i += 4096) {
        try aetherpage.map_page(
            HEAP_START + i,
            HEAP_START + i,
            .{
                .present = true,
                .writable = true,
                .user_accessible = false,
                .cache_disabled = false,
            }
        );
    }

    // Initialize first block
    heap_start = @intToPtr(*BlockHeader, HEAP_START);
    heap_start.* = BlockHeader{
        .size = HEAP_INITIAL_SIZE,
        .is_free = true,
        .prev = null,
        .next = null,
        .core_affinity = .Any,
        .cache_hint = 0,
        .access_count = 0,
    };

    // Initialize cache pools
    cache_pools = CachePool{
        .l1_blocks = null,
        .l2_blocks = null,
        .l3_blocks = null,
        .uncached_blocks = null,
    };

    heap_initialized = true;
}

// Allocate memory with cache and core optimizations
pub fn alloc(size: usize, core_type: CoreType) ?*anyopaque {
    const aligned_size = align_size(size + @sizeOf(BlockHeader));
    if (aligned_size < MIN_BLOCK_SIZE) return null;

    // Try to find block in appropriate cache pool
    var block = find_cached_block(aligned_size);
    if (block == null) {
        block = find_free_block(aligned_size);
        stats.cache_misses += 1;
    } else {
        stats.cache_hits += 1;
    }

    if (block) |b| {
        return prepare_block(b, aligned_size, core_type);
    }

    return null;
}

fn find_cached_block(size: usize) ?*BlockHeader {
    // Try to find block in appropriate cache pool based on size
    if (size <= L1_CACHE_SIZE) {
        if (cache_pools.l1_blocks) |block| {
            if (block.size >= size) return block;
        }
    } else if (size <= L2_CACHE_SIZE) {
        if (cache_pools.l2_blocks) |block| {
            if (block.size >= size) return block;
        }
    } else if (size <= L3_CACHE_SIZE) {
        if (cache_pools.l3_blocks) |block| {
            if (block.size >= size) return block;
        }
    }
    return cache_pools.uncached_blocks;
}

fn prepare_block(block: *BlockHeader, size: usize, core_type: CoreType) *anyopaque {
    const remaining_size = block.size - size;

    if (remaining_size >= MIN_BLOCK_SIZE) {
        // Split block if remaining size is usable
        const new_block = @intToPtr(*BlockHeader, @ptrToInt(block) + size);
        new_block.* = BlockHeader{
            .size = remaining_size,
            .is_free = true,
            .prev = block,
            .next = block.next,
            .core_affinity = .Any,
            .cache_hint = 0,
            .access_count = 0,
        };

        if (block.next) |next| {
            next.prev = new_block;
        }

        block.next = new_block;
        block.size = size;
    }

    block.is_free = false;
    block.core_affinity = core_type;
    block.cache_hint = determine_cache_hint(size);

    stats.total_allocations += 1;
    stats.current_usage += size;
    if (stats.current_usage > stats.peak_usage) {
        stats.peak_usage = stats.current_usage;
    }

    return @intToPtr(*anyopaque, @ptrToInt(block) + @sizeOf(BlockHeader));
}

fn determine_cache_hint(size: usize) u8 {
    if (size <= L1_CACHE_SIZE) return 1;
    if (size <= L2_CACHE_SIZE) return 2;
    if (size <= L3_CACHE_SIZE) return 3;
    return 0;
}

// Free memory and update cache pools
pub fn free(ptr: *anyopaque) void {
    const block = @intToPtr(*BlockHeader, @ptrToInt(ptr) - @sizeOf(BlockHeader));
    block.is_free = true;

    // Coalesce with adjacent free blocks
    coalesce_blocks(block);

    // Update cache pools
    update_cache_pools(block);

    stats.total_frees += 1;
    stats.current_usage -= block.size;
}

fn update_cache_pools(block: *BlockHeader) void {
    // Add block to appropriate cache pool based on size
    if (block.size <= L1_CACHE_SIZE) {
        block.next = cache_pools.l1_blocks;
        cache_pools.l1_blocks = block;
    } else if (block.size <= L2_CACHE_SIZE) {
        block.next = cache_pools.l2_blocks;
        cache_pools.l2_blocks = block;
    } else if (block.size <= L3_CACHE_SIZE) {
        block.next = cache_pools.l3_blocks;
        cache_pools.l3_blocks = block;
    } else {
        block.next = cache_pools.uncached_blocks;
        cache_pools.uncached_blocks = block;
    }
}

fn coalesce_blocks(block: *BlockHeader) void {
    // Coalesce with next block if free
    if (block.next) |next| {
        if (next.is_free) {
            block.size += next.size;
            block.next = next.next;
            if (next.next) |next_next| {
                next_next.prev = block;
            }
        }
    }

    // Coalesce with previous block if free
    if (block.prev) |prev| {
        if (prev.is_free) {
            prev.size += block.size;
            prev.next = block.next;
            if (block.next) |next| {
                next.prev = prev;
            }
        }
    }
}

// Utility functions
fn align_size(size: usize) usize {
    return (size + (CACHE_LINE_SIZE - 1)) & ~(CACHE_LINE_SIZE - 1);
}

// Get allocation statistics
pub fn get_stats() struct {
    total_allocs: usize,
    total_frees: usize,
    current_usage: usize,
    peak_usage: usize,
    cache_hit_rate: f32,
} {
    const total_cache_ops = stats.cache_hits + stats.cache_misses;
    const cache_hit_rate = if (total_cache_ops > 0)
        @intToFloat(f32, stats.cache_hits) / @intToFloat(f32, total_cache_ops)
    else
        0.0;

    return .{
        .total_allocs = stats.total_allocations,
        .total_frees = stats.total_frees,
        .current_usage = stats.current_usage,
        .peak_usage = stats.peak_usage,
        .cache_hit_rate = cache_hit_rate,
    };
}

// Debug function to print heap state
pub fn debug_print_heap() void {
    var current = heap_start;
    var block_count: usize = 0;

    while (current) |curr| : (current = curr.next) {
        std.debug.print(
            "Block {}: size={}, free={}, core={}, cache={}\n",
            .{
                block_count,
                curr.size,
                curr.is_free,
                curr.core_affinity,
                curr.cache_hint,
            }
        );
        block_count += 1;
    }
}
