const std = @import("std");

// CPU Feature Control Bits
const CR4_OSXSAVE: u64 = 1 << 18;
const CR4_PAE: u64 = 1 << 5;
const CR4_PGE: u64 = 1 << 7;

// MSR Addresses
const IA32_MISC_ENABLE: u32 = 0x1A0;
const IA32_MTRR_DEF_TYPE: u32 = 0x2FF;
const IA32_MTRRCAP: u32 = 0xFE;
const IA32_PAT: u32 = 0x277;

// Cache Types for PAT/MTRR
const CACHE_TYPE_WB: u8 = 0x06;  // Write-Back
const CACHE_TYPE_WT: u8 = 0x04;  // Write-Through
const CACHE_TYPE_UC: u8 = 0x00;  // Uncacheable

// i3-1215U Cache Configuration
const L1_CACHE_SIZE: usize = 224 * 1024;      // 224KB L1 data cache (48KB per core)
const L2_CACHE_SIZE: usize = 4608 * 1024;     // 4.5MB L2 cache
const L3_CACHE_SIZE: usize = 10240 * 1024;    // 10MB L3 cache
const CACHE_LINE_SIZE: usize = 64;            // 64 bytes per cache line

pub const CacheConfig = struct {
    l1_size: usize,
    l2_size: usize,
    l3_size: usize,
    line_size: usize,
    prefetch_enabled: bool,
};

pub fn initializeCPU() !void {
    try enableExtendedFeatures();
    try configureCacheControl();
    try setupMemoryTypes();
    try configurePowerStates();
}

fn enableExtendedFeatures() !void {
    // Enable XSAVE and extended processor features
    var cr4 = asm volatile ("mov %%cr4, %[ret]"
        : [ret] "={rax}" (-> u64)
    );
    cr4 |= CR4_OSXSAVE | CR4_PAE | CR4_PGE;
    asm volatile ("mov %[val], %%cr4"
        :
        : [val] "{rax}" (cr4)
    );

    // Enable hardware prefetching and other performance features
    var low: u32 = undefined;
    var high: u32 = undefined;
    asm volatile ("rdmsr"
        : [_] "={eax}" (low),
          [_] "={edx}" (high)
        : [_] "{ecx}" (IA32_MISC_ENABLE)
    );

    // Enable hardware prefetching
    low &= ~(1 << 9);  // Adjacent Cache Line Prefetch
    low &= ~(1 << 19); // Hardware Prefetcher

    asm volatile ("wrmsr"
        :
        : [_] "{ecx}" (IA32_MISC_ENABLE),
          [_] "{eax}" (low),
          [_] "{edx}" (high)
    );
}

fn configureCacheControl() !void {
    // Configure MTRR for optimal cache usage
    var mtrr_cap_low: u32 = undefined;
    var mtrr_cap_high: u32 = undefined;
    asm volatile ("rdmsr"
        : [_] "={eax}" (mtrr_cap_low),
          [_] "={edx}" (mtrr_cap_high)
        : [_] "{ecx}" (IA32_MTRRCAP)
    );

    // Enable MTRR
    var def_type_low: u32 = undefined;
    var def_type_high: u32 = undefined;
    asm volatile ("rdmsr"
        : [_] "={eax}" (def_type_low),
          [_] "={edx}" (def_type_high)
        : [_] "{ecx}" (IA32_MTRR_DEF_TYPE)
    );
    def_type_low |= (1 << 11); // Enable MTRR
    asm volatile ("wrmsr"
        :
        : [_] "{ecx}" (IA32_MTRR_DEF_TYPE),
          [_] "{eax}" (def_type_low),
          [_] "{edx}" (def_type_high)
    );
}

fn setupMemoryTypes() !void {
    // Configure PAT (Page Attribute Table)
    // Set up different memory types for different regions
    // PAT entries: WB, WT, UC-/WC, UC
    const pat_value: u64 =
        @as(u64, CACHE_TYPE_WB) |
        (@as(u64, CACHE_TYPE_WT) << 8) |
        (@as(u64, CACHE_TYPE_UC) << 16) |
        (@as(u64, CACHE_TYPE_WB) << 24) |
        (@as(u64, CACHE_TYPE_WT) << 32) |
        (@as(u64, CACHE_TYPE_UC) << 40) |
        (@as(u64, CACHE_TYPE_WB) << 48) |
        (@as(u64, CACHE_TYPE_UC) << 56);

    asm volatile ("wrmsr"
        :
        : [_] "{ecx}" (IA32_PAT),
          [_] "{eax}" (@truncate(u32, pat_value)),
          [_] "{edx}" (@truncate(u32, pat_value >> 32))
    );
}

fn configurePowerStates() !void {
    // Set up P-states for the i3-1215U
    // Base frequency: 1.2 GHz
    // Max turbo: 4.4 GHz
    const base_ratio = 12; // 1.2 GHz
    const max_ratio = 44;  // 4.4 GHz

    // Configure P-state 0 (max performance)
    asm volatile ("wrmsr"
        :
        : [_] "{ecx}" (0x199), // IA32_PERF_CTL
          [_] "{eax}" (max_ratio << 8),
          [_] "{edx}" (0)
    );
}

pub fn getCacheConfiguration() CacheConfig {
    return CacheConfig{
        .l1_size = L1_CACHE_SIZE,
        .l2_size = L2_CACHE_SIZE,
        .l3_size = L3_CACHE_SIZE,
        .line_size = CACHE_LINE_SIZE,
        .prefetch_enabled = true,
    };
}

pub fn invalidateCacheLine(addr: usize) void {
    asm volatile ("clflush (%[addr])"
        :
        : [addr] "r" (addr)
        : "memory"
    );
}

pub fn invalidateCacheRange(start: usize, size: usize) void {
    var addr = start;
    const end = start + size;
    while (addr < end) : (addr += CACHE_LINE_SIZE) {
        invalidateCacheLine(addr);
    }
}

pub fn prefetchCacheLine(addr: usize) void {
    asm volatile ("prefetcht0 (%[addr])"
        :
        : [addr] "r" (addr)
    );
}
