const std = @import("std");
const paging = @import("paging.zig");

// Memory map entry types from BIOS/UEFI
pub const E820EntryType = enum(u32) {
    Usable = 1,
    Reserved = 2,
    ACPI_Reclaimable = 3,
    ACPI_NVS = 4,
    Bad = 5,
};

pub const MemoryMapEntry = struct {
    base: u64,
    length: u64,
    entry_type: E820EntryType,
};

// Bitmap for tracking physical page usage
const PageBitmap = struct {
    bitmap: []u64,
    total_pages: usize,

    pub fn init(bitmap_addr: [*]u64, total_pages: usize) PageBitmap {
        const bitmap_size = (total_pages + 63) / 64;
        return PageBitmap{
            .bitmap = bitmap_addr[0..bitmap_size],
            .total_pages = total_pages,
        };
    }

    pub fn setPage(self: *PageBitmap, page_index: usize) void {
        const bitmap_index = page_index / 64;
        const bit_index = page_index % 64;
        self.bitmap[bitmap_index] |= @as(u64, 1) << @intCast(u6, bit_index);
    }

    pub fn clearPage(self: *PageBitmap, page_index: usize) void {
        const bitmap_index = page_index / 64;
        const bit_index = page_index % 64;
        self.bitmap[bitmap_index] &= ~(@as(u64, 1) << @intCast(u6, bit_index));
    }

    pub fn isPageSet(self: *PageBitmap, page_index: usize) bool {
        const bitmap_index = page_index / 64;
        const bit_index = page_index % 64;
        return (self.bitmap[bitmap_index] & (@as(u64, 1) << @intCast(u6, bit_index))) != 0;
    }
};

pub const PhysicalMemoryManager = struct {
    page_bitmap: PageBitmap,
    memory_size: usize,
    free_pages: usize,

    pub fn init(memory_map: []const MemoryMapEntry, bitmap_addr: [*]u64) !PhysicalMemoryManager {
        var max_address: usize = 0;

        // Find total memory size from memory map
        for (memory_map) |entry| {
            const end_addr = entry.base + entry.length;
            if (end_addr > max_address) {
                max_address = end_addr;
            }
        }

        const total_pages = max_address / paging.PAGE_SIZE;
        var manager = PhysicalMemoryManager{
            .page_bitmap = PageBitmap.init(bitmap_addr, total_pages),
            .memory_size = max_address,
            .free_pages = 0,
        };

        // Mark all pages as used initially
        var i: usize = 0;
        while (i < total_pages) : (i += 1) {
            manager.page_bitmap.setPage(i);
        }

        // Mark free pages based on memory map
        for (memory_map) |entry| {
            if (entry.entry_type == .Usable) {
                const start_page = entry.base / paging.PAGE_SIZE;
                const end_page = (entry.base + entry.length) / paging.PAGE_SIZE;
                var page = start_page;
                while (page < end_page) : (page += 1) {
                    manager.page_bitmap.clearPage(page);
                    manager.free_pages += 1;
                }
            }
        }

        return manager;
    }

    pub fn allocatePage(self: *PhysicalMemoryManager) ?usize {
        var page: usize = 0;
        while (page < self.page_bitmap.total_pages) : (page += 1) {
            if (!self.page_bitmap.isPageSet(page)) {
                self.page_bitmap.setPage(page);
                self.free_pages -= 1;
                return page * paging.PAGE_SIZE;
            }
        }
        return null;
    }

    pub fn allocateLargePage(self: *PhysicalMemoryManager) ?usize {
        // Try to find 2MB-aligned free space
        var page: usize = 0;
        const pages_per_large = paging.LARGE_PAGE_SIZE / paging.PAGE_SIZE;

        while (page < self.page_bitmap.total_pages - pages_per_large) : (page += pages_per_large) {
            if (page * paging.PAGE_SIZE % paging.LARGE_PAGE_SIZE != 0) continue;

            var is_free = true;
            var i: usize = 0;
            while (i < pages_per_large) : (i += 1) {
                if (self.page_bitmap.isPageSet(page + i)) {
                    is_free = false;
                    break;
                }
            }

            if (is_free) {
                i = 0;
                while (i < pages_per_large) : (i += 1) {
                    self.page_bitmap.setPage(page + i);
                }
                self.free_pages -= pages_per_large;
                return page * paging.PAGE_SIZE;
            }
        }
        return null;
    }

    pub fn freePage(self: *PhysicalMemoryManager, addr: usize) void {
        const page = addr / paging.PAGE_SIZE;
        if (page < self.page_bitmap.total_pages) {
            self.page_bitmap.clearPage(page);
            self.free_pages += 1;
        }
    }

    pub fn freeLargePage(self: *PhysicalMemoryManager, addr: usize) void {
        const start_page = addr / paging.PAGE_SIZE;
        const pages_per_large = paging.LARGE_PAGE_SIZE / paging.PAGE_SIZE;

        var i: usize = 0;
        while (i < pages_per_large) : (i += 1) {
            self.page_bitmap.clearPage(start_page + i);
        }
        self.free_pages += pages_per_large;
    }
};
