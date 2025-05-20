const std = @import("std");

pub const PAGE_SIZE: usize = 4096;
pub const LARGE_PAGE_SIZE: usize = 2 * 1024 * 1024; // 2MB pages for better TLB utilization
pub const CACHE_LINE_SIZE: usize = 64; // Intel's typical cache line size

// Virtual memory layout constants
pub const KERNEL_VIRTUAL_BASE: usize = 0xFFFF800000000000;
pub const USER_SPACE_END: usize = 0x0000800000000000;

pub const PageTableEntry = packed struct {
    present: bool,
    writable: bool,
    user_accessible: bool,
    write_through: bool,
    cache_disabled: bool,
    accessed: bool,
    dirty: bool,
    huge_page: bool,
    global: bool,
    _available1: u3,
    address: u52,
};

pub const PageTable = struct {
    entries: [512]PageTableEntry,
    next_tables: [512]?*PageTable,

    pub fn init() PageTable {
        return PageTable{
            .entries = std.mem.zeroes([512]PageTableEntry),
            .next_tables = [_]?*PageTable{null} ** 512,
        };
    }

    pub fn mapPage(self: *PageTable, virtual_addr: usize, physical_addr: usize, flags: PageTableEntry) !void {
        const pml4_index = (virtual_addr >> 39) & 0x1FF;
        const pdpt_index = (virtual_addr >> 30) & 0x1FF;
        const pd_index = (virtual_addr >> 21) & 0x1FF;
        const pt_index = (virtual_addr >> 12) & 0x1FF;

        // Ensure all page table levels exist
        if (self.next_tables[pml4_index] == null) {
            const new_table = try allocatePageTable();
            self.next_tables[pml4_index] = new_table;
            self.entries[pml4_index] = PageTableEntry{
                .present = true,
                .writable = true,
                .user_accessible = flags.user_accessible,
                .write_through = false,
                .cache_disabled = false,
                .accessed = false,
                .dirty = false,
                .huge_page = false,
                .global = false,
                ._available1 = 0,
                .address = @truncate(@ptrToInt(new_table) >> 12),
            };
        }

        var pdpt = self.next_tables[pml4_index].?;
        if (pdpt.next_tables[pdpt_index] == null) {
            const new_table = try allocatePageTable();
            pdpt.next_tables[pdpt_index] = new_table;
            pdpt.entries[pdpt_index] = PageTableEntry{
                .present = true,
                .writable = true,
                .user_accessible = flags.user_accessible,
                .write_through = false,
                .cache_disabled = false,
                .accessed = false,
                .dirty = false,
                .huge_page = false,
                .global = false,
                ._available1 = 0,
                .address = @truncate(@ptrToInt(new_table) >> 12),
            };
        }

        // Support for 2MB huge pages
        if (flags.huge_page) {
            var pd = pdpt.next_tables[pdpt_index].?;
            pd.entries[pd_index] = flags;
            pd.entries[pd_index].address = @truncate(physical_addr >> 21);
            return;
        }

        // Regular 4KB pages
        var pd = pdpt.next_tables[pdpt_index].?;
        if (pd.next_tables[pd_index] == null) {
            const new_table = try allocatePageTable();
            pd.next_tables[pd_index] = new_table;
            pd.entries[pd_index] = PageTableEntry{
                .present = true,
                .writable = true,
                .user_accessible = flags.user_accessible,
                .write_through = false,
                .cache_disabled = false,
                .accessed = false,
                .dirty = false,
                .huge_page = false,
                .global = false,
                ._available1 = 0,
                .address = @truncate(@ptrToInt(new_table) >> 12),
            };
        }

        var pt = pd.next_tables[pd_index].?;
        pt.entries[pt_index] = flags;
        pt.entries[pt_index].address = @truncate(physical_addr >> 12);
    }

    pub fn unmapPage(self: *PageTable, virtual_addr: usize) void {
        const pml4_index = (virtual_addr >> 39) & 0x1FF;
        const pdpt_index = (virtual_addr >> 30) & 0x1FF;
        const pd_index = (virtual_addr >> 21) & 0x1FF;
        const pt_index = (virtual_addr >> 12) & 0x1FF;

        if (self.next_tables[pml4_index]) |pdpt| {
            if (pdpt.next_tables[pdpt_index]) |pd| {
                if (pd.next_tables[pd_index]) |pt| {
                    pt.entries[pt_index].present = false;
                    invalidateTLB(virtual_addr);
                }
            }
        }
    }
};

fn allocatePageTable() !*PageTable {
    // This should be replaced with proper physical memory allocation
    var table = @ptrCast(*PageTable, @alignCast(@alignOf(PageTable), try allocPhysicalPage()));
    table.* = PageTable.init();
    return table;
}

fn allocPhysicalPage() !*align(PAGE_SIZE) [PAGE_SIZE]u8 {
    // Temporary implementation - should be replaced with proper physical memory manager
    const memory = try std.heap.page_allocator.alignedAlloc(u8, PAGE_SIZE, PAGE_SIZE);
    return @ptrCast(*align(PAGE_SIZE) [PAGE_SIZE]u8, memory.ptr);
}

// Intel specific cache control
pub fn invalidateTLB(addr: usize) void {
    asm volatile ("invlpg (%[addr])"
        :
        : [addr] "r" (addr)
        : "memory"
    );
}

pub fn enablePaging() void {
    // Enable PAE (Physical Address Extension)
    asm volatile ("movl %%cr4, %%eax\n"
        "orl $0x20, %%eax\n"
        "movl %%eax, %%cr4\n"
        ::: "eax", "memory");

    // Enable long mode in EFER MSR
    asm volatile ("movl $0xC0000080, %%ecx\n"
        "rdmsr\n"
        "orl $0x100, %%eax\n"
        "wrmsr\n"
        ::: "eax", "ecx", "edx");

    // Enable paging in CR0
    asm volatile ("movl %%cr0, %%eax\n"
        "orl $0x80000000, %%eax\n"
        "movl %%eax, %%cr0\n"
        ::: "eax", "memory");
}
