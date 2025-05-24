const std = @import("std");
const log = @import("../seer/oracle.zig").log;

// Page size constants
const PAGE_SIZE: u64 = 4096;
const LARGE_PAGE_SIZE: u64 = 2 * 1024 * 1024;
const HUGE_PAGE_SIZE: u64 = 1024 * 1024 * 1024;

// CPU-specific cache parameters (Intel i3-1215U)
const L1_CACHE_SIZE: u32 = 80 * 1024;     // 80KB L1 (per core)
const L2_CACHE_SIZE: u32 = 1536 * 1024;   // 1.5MB L2 (per core)
const L3_CACHE_SIZE: u32 = 10 * 1024 * 1024; // 10MB L3 (shared)
const CACHE_LINE_SIZE: u32 = 64;          // 64 bytes

// Page table entry flags
const PageFlags = packed struct {
    present: bool = false,
    writable: bool = false,
    user_accessible: bool = false,
    write_through: bool = false,
    cache_disabled: bool = false,
    accessed: bool = false,
    dirty: bool = false,
    huge_page: bool = false,
    global: bool = false,
    available: u3 = 0,
    pat: bool = false,
    reserved: u8 = 0,
    physical_address: u40 = 0,
};

// Extended page attributes for hybrid core optimization
const PageAttributes = struct {
    core_preference: CoreType,    // P-core or E-core preference
    cache_level: u8,             // Preferred cache level
    access_frequency: u32,       // Access count for adaptive placement
    last_access: u64,           // Timestamp of last access
};

// Core types for Intel hybrid architecture
const CoreType = enum {
    P_Core,  // Performance core
    E_Core,  // Efficiency core
    Any,     // No preference
};

// Memory region types
const MemoryRegionType = enum {
    Available,
    Reserved,
    ACPI_Reclaimable,
    ACPI_NVS,
    Bad,
    Kernel,
    Modules,
};

// Memory map entry
const MemoryMapEntry = struct {
    base_addr: u64,
    length: u64,
    region_type: MemoryRegionType,
};

// Page table structure
const PageTable = struct {
    entries: [512]u64 align(PAGE_SIZE) = [_]u64{0} ** 512,

    pub fn get_entry(self: *PageTable, index: usize) PageFlags {
        const entry = self.entries[index];
        return @bitCast(PageFlags, entry);
    }

    pub fn set_entry(self: *PageTable, index: usize, flags: PageFlags) void {
        self.entries[index] = @bitCast(u64, flags);
    }
};

// Paging context
var pml4: PageTable align(PAGE_SIZE) = PageTable{};
var page_directory_ptr: [512]PageTable align(PAGE_SIZE) = undefined;
var page_directories: [512][512]PageTable align(PAGE_SIZE) = undefined;
var page_tables: [512][512][512]PageTable align(PAGE_SIZE) = undefined;

// Page table management
var pml4_table: *PageTable = undefined;
var memory_map: []MemoryMapEntry = undefined;
var free_pages: std.ArrayList(u64) = undefined;
var page_attributes: std.AutoHashMap(u64, PageAttributes) = undefined;

// Initialize paging structures
pub fn init_paging() void {
    // Clear all tables
    @memset(@ptrCast([*]u8, &pml4), 0, @sizeOf(PageTable));
    @memset(@ptrCast([*]u8, &page_directory_ptr), 0, @sizeOf(@TypeOf(page_directory_ptr)));
    @memset(@ptrCast([*]u8, &page_directories), 0, @sizeOf(@TypeOf(page_directories)));
    @memset(@ptrCast([*]u8, &page_tables), 0, @sizeOf(@TypeOf(page_tables)));

    // Identity map first 1GB with 2MB pages
    var i: usize = 0;
    while (i < 512) : (i += 1) {
        const pdp_flags = PageFlags{
            .present = true,
            .writable = true,
            .physical_address = @ptrToInt(&page_directories[0]) >> 12,
        };
        pml4.set_entry(0, pdp_flags);

        if (i < 512) {
            const pd_flags = PageFlags{
                .present = true,
                .writable = true,
                .huge_page = true,
                .physical_address = (i * LARGE_PAGE_SIZE) >> 12,
            };
            page_directories[0][i].entries[0] = @bitCast(u64, pd_flags);
        }
    }

    // Load PML4 into CR3
    const cr3 = @ptrToInt(&pml4);
    asm volatile ("mov %[cr3], %%cr3"
        :
        : [cr3] "r" (cr3)
    );
}

// Map a virtual address to a physical address
pub fn map_page(virtual_addr: u64, physical_addr: u64, flags: PageFlags) !void {
    const pml4_index = (virtual_addr >> 39) & 0x1FF;
    const pdp_index = (virtual_addr >> 30) & 0x1FF;
    const pd_index = (virtual_addr >> 21) & 0x1FF;
    const pt_index = (virtual_addr >> 12) & 0x1FF;

    // Ensure PML4 entry exists
    if (!pml4.get_entry(pml4_index).present) {
        const pdp_flags = PageFlags{
            .present = true,
            .writable = true,
            .physical_address = @ptrToInt(&page_directory_ptr[pml4_index]) >> 12,
        };
        pml4.set_entry(pml4_index, pdp_flags);
    }

    // Ensure PDPT entry exists
    if (!page_directory_ptr[pml4_index].get_entry(pdp_index).present) {
        const pd_flags = PageFlags{
            .present = true,
            .writable = true,
            .physical_address = @ptrToInt(&page_directories[pml4_index][pdp_index]) >> 12,
        };
        page_directory_ptr[pml4_index].set_entry(pdp_index, pd_flags);
    }

    // Ensure PD entry exists
    if (!page_directories[pml4_index][pdp_index].get_entry(pd_index).present) {
        const pt_flags = PageFlags{
            .present = true,
            .writable = true,
            .physical_address = @ptrToInt(&page_tables[pml4_index][pdp_index][pd_index]) >> 12,
        };
        page_directories[pml4_index][pdp_index].set_entry(pd_index, pt_flags);
    }

    // Map the actual page
    var final_flags = flags;
    final_flags.physical_address = physical_addr >> 12;
    page_tables[pml4_index][pdp_index][pd_index].set_entry(pt_index, final_flags);

    // Invalidate TLB for this page
    asm volatile ("invlpg (%[addr])"
        :
        : [addr] "r" (virtual_addr)
    );
}

// Unmap a virtual address
pub fn unmap_page(virtual_addr: u64) void {
    const pml4_index = (virtual_addr >> 39) & 0x1FF;
    const pdp_index = (virtual_addr >> 30) & 0x1FF;
    const pd_index = (virtual_addr >> 21) & 0x1FF;
    const pt_index = (virtual_addr >> 12) & 0x1FF;

    if (page_tables[pml4_index][pdp_index][pd_index].get_entry(pt_index).present) {
        page_tables[pml4_index][pdp_index][pd_index].entries[pt_index] = 0;

        // Invalidate TLB for this page
        asm volatile ("invlpg (%[addr])"
            :
            : [addr] "r" (virtual_addr)
        );
    }
}

// Extended functionality for hybrid core support
// Enable advanced CPU features
fn enable_cpu_features() void {
    // Enable PAT (Page Attribute Table)
    var pat_value: u64 = 0;
    pat_value |= @as(u64, 0x6) << 0;  // WB (Write-Back)
    pat_value |= @as(u64, 0x4) << 8;  // WT (Write-Through)
    pat_value |= @as(u64, 0x1) << 16; // UC- (Uncacheable)
    pat_value |= @as(u64, 0x0) << 24; // UC (Uncacheable)
    write_msr(0x277, pat_value);

    // Enable other CPU-specific features
    enable_nx();          // Enable NX bit
    enable_global_pages(); // Enable global pages
}

// Utility functions
fn write_msr(msr: u32, value: u64) void {
    asm volatile ("wrmsr"
        :
        : [msr] "{ecx}" (msr),
          [low] "{eax}" (@truncate(u32, value)),
          [high] "{edx}" (@truncate(u32, value >> 32))
    );
}

fn invalidate_tlb(addr: u64) void {
    asm volatile ("invlpg [%[addr]]"
        :
        : [addr] "r" (addr)
        : "memory"
    );
}

// Memory attribute management
fn init_page_attributes() !void {
    page_attributes = std.AutoHashMap(u64, PageAttributes).init(
        std.heap.page_allocator
    );
}

pub fn set_page_attributes(virt: u64, attrs: PageAttributes) !void {
    try page_attributes.put(virt, attrs);
}

pub fn get_page_attributes(virt: u64) ?PageAttributes {
    return page_attributes.get(virt);
}
