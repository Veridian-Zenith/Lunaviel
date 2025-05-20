const std = @import("std");
const paging = @import("paging.zig");
const PhysicalMemoryManager = @import("physical_memory.zig").PhysicalMemoryManager;

pub const VirtualMemoryRegion = struct {
    start: usize,
    size: usize,
    flags: struct {
        readable: bool = true,
        writable: bool = false,
        executable: bool = false,
        user_accessible: bool = false,
    },
};

pub const VirtualMemoryManager = struct {
    root_table: *paging.PageTable,
    phys_mem: *PhysicalMemoryManager,
    kernel_heap_start: usize,
    kernel_heap_end: usize,

    pub fn init(phys_mem: *PhysicalMemoryManager, root_table_phys: usize) !VirtualMemoryManager {
        const root = @intToPtr(*paging.PageTable, root_table_phys);
        return VirtualMemoryManager{
            .root_table = root,
            .phys_mem = phys_mem,
            .kernel_heap_start = paging.KERNEL_VIRTUAL_BASE + 0x1000000,
            .kernel_heap_end = paging.KERNEL_VIRTUAL_BASE + 0x10000000,
        };
    }

    pub fn mapRegion(self: *VirtualMemoryManager, region: VirtualMemoryRegion, physical_start: ?usize) !void {
        var offset: usize = 0;
        while (offset < region.size) : (offset += paging.PAGE_SIZE) {
            const virt_addr = region.start + offset;
            const phys_addr = if (physical_start) |p| p + offset else try self.phys_mem.allocatePage() orelse return error.OutOfMemory;

            try self.root_table.mapPage(virt_addr, phys_addr, .{
                .present = true,
                .writable = region.flags.writable,
                .user_accessible = region.flags.user_accessible,
                .write_through = false,
                .cache_disabled = false,
                .accessed = false,
                .dirty = false,
                .huge_page = false,
                .global = !region.flags.user_accessible,
                ._available1 = 0,
                .address = undefined, // Will be set by mapPage
            });
        }
    }

    pub fn mapLargeRegion(self: *VirtualMemoryManager, region: VirtualMemoryRegion, physical_start: ?usize) !void {
        var offset: usize = 0;
        while (offset < region.size) : (offset += paging.LARGE_PAGE_SIZE) {
            const virt_addr = region.start + offset;
            const phys_addr = if (physical_start) |p|
                p + offset
            else
                try self.phys_mem.allocateLargePage() orelse return error.OutOfMemory;

            // Ensure address is 2MB aligned
            if (virt_addr % paging.LARGE_PAGE_SIZE != 0 or phys_addr % paging.LARGE_PAGE_SIZE != 0) {
                return error.MisalignedAddress;
            }

            try self.root_table.mapPage(virt_addr, phys_addr, .{
                .present = true,
                .writable = region.flags.writable,
                .user_accessible = region.flags.user_accessible,
                .write_through = false,
                .cache_disabled = false,
                .accessed = false,
                .dirty = false,
                .huge_page = true,
                .global = !region.flags.user_accessible,
                ._available1 = 0,
                .address = undefined, // Will be set by mapPage
            });
        }
    }

    pub fn unmapRegion(self: *VirtualMemoryManager, region: VirtualMemoryRegion) void {
        var offset: usize = 0;
        while (offset < region.size) : (offset += paging.PAGE_SIZE) {
            const virt_addr = region.start + offset;
            self.root_table.unmapPage(virt_addr);
        }
    }

    pub fn createAddressSpace() !*paging.PageTable {
        const phys_addr = (try self.phys_mem.allocatePage()) orelse return error.OutOfMemory;
        const new_root = @intToPtr(*paging.PageTable, phys_addr);
        new_root.* = paging.PageTable.init();
        return new_root;
    }

    pub fn expandKernelHeap(self: *VirtualMemoryManager, additional_pages: usize) !void {
        const new_end = self.kernel_heap_end + (additional_pages * paging.PAGE_SIZE);
        try self.mapRegion(.{
            .start = self.kernel_heap_end,
            .size = additional_pages * paging.PAGE_SIZE,
            .flags = .{
                .writable = true,
                .executable = false,
                .user_accessible = false,
            },
        }, null);
        self.kernel_heap_end = new_end;
    }
};
