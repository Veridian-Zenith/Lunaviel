const std = @import("std");
const paging = @import("paging.zig");

// Constants tuned for the Intel i3-1215U
const CACHE_LINE_SIZE: usize = 64;
const L1_CACHE_SIZE: usize = 224 * 1024; // L1 data cache
const L2_CACHE_SIZE: usize = 4.5 * 1024 * 1024;
const L3_CACHE_SIZE: usize = 10 * 1024 * 1024;

const BlockHeader = struct {
    size: usize,
    next: ?*BlockHeader,
    free: bool,
};

pub const HeapAllocator = struct {
    heap_start: [*]u8,
    heap_end: [*]u8,
    free_list: ?*BlockHeader,

    pub fn init(start: [*]u8, size: usize) HeapAllocator {
        var allocator = HeapAllocator{
            .heap_start = start,
            .heap_end = start + size,
            .free_list = null,
        };

        // Create initial free block
        var initial_block = @ptrCast(*BlockHeader, start);
        initial_block.* = BlockHeader{
            .size = size - @sizeOf(BlockHeader),
            .next = null,
            .free = true,
        };
        allocator.free_list = initial_block;

        return allocator;
    }

    pub fn allocate(self: *HeapAllocator, size: usize) ?[*]u8 {
        // Align size to cache line for better performance
        const aligned_size = (size + (CACHE_LINE_SIZE - 1)) & ~(CACHE_LINE_SIZE - 1);

        var current = self.free_list;
        var prev: ?*BlockHeader = null;

        // First fit strategy with alignment
        while (current) |block| {
            if (block.free and block.size >= aligned_size) {
                if (block.size > aligned_size + @sizeOf(BlockHeader) + CACHE_LINE_SIZE) {
                    // Split block if there's enough space for another allocation
                    const new_block = @intToPtr(*BlockHeader, @ptrToInt(block) + @sizeOf(BlockHeader) + aligned_size);
                    new_block.* = BlockHeader{
                        .size = block.size - aligned_size - @sizeOf(BlockHeader),
                        .next = block.next,
                        .free = true,
                    };
                    block.size = aligned_size;
                    block.next = new_block;
                }

                block.free = false;
                return @intToPtr([*]u8, @ptrToInt(block) + @sizeOf(BlockHeader));
            }

            prev = block;
            current = block.next;
        }

        return null;
    }

    pub fn free(self: *HeapAllocator, ptr: [*]u8) void {
        const block = @intToPtr(*BlockHeader, @ptrToInt(ptr) - @sizeOf(BlockHeader));
        block.free = true;

        // Coalesce with next block if it's free
        if (block.next) |next| {
            if (next.free) {
                block.size += @sizeOf(BlockHeader) + next.size;
                block.next = next.next;
            }
        }

        // Coalesce with previous block if it's free
        var current = self.free_list;
        while (current) |curr| {
            if (curr.next == block and curr.free) {
                curr.size += @sizeOf(BlockHeader) + block.size;
                curr.next = block.next;
                break;
            }
            current = curr.next;
        }
    }
};
