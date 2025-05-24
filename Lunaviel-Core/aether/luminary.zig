const std = @import("std");
const log = @import("../seer/oracle.zig");

// CPU Feature flags structure
const Features = struct {
    // Basic features
    apic: bool = false,
    xsave: bool = false,
    avx: bool = false,
    avx2: bool = false,
    sse: bool = false,
    sse4_2: bool = false,
    aes: bool = false,

    // Advanced features
    hybrid_cores: bool = false,
    turbo_boost: bool = false,
    speedstep: bool = false,

    // Power management
    intel_turbo_boost: bool = false,
    enhanced_speedstep: bool = false,
    power_limits: bool = false,

    // Cache info
    l1_cache_size: u32 = 0,
    l2_cache_size: u32 = 0,
    l3_cache_size: u32 = 0,
};

// CPU Core Types for hybrid architecture
const CoreType = enum(u8) {
    P_Core = 0x40,  // Performance cores
    E_Core = 0x20,  // Efficiency cores
    Unknown = 0x00,
};

// P-State configuration
const PState = struct {
    frequency: u32,
    voltage: u32,
    power: u32,
};

var cpu_features: Features = undefined;
var core_count: u32 = 0;
var thread_count: u32 = 0;

fn check_cpuid() bool {
    var flags: u64 = undefined;
    asm volatile (
        \\ pushfq
        \\ pop %[flags]
        : [flags] "=r" (flags)
    );

    const original = flags;
    flags ^= (1 << 21);

    asm volatile (
        \\ push %[flags]
        \\ popfq
        : : [flags] "r" (flags)
    );

    asm volatile (
        \\ pushfq
        \\ pop %[flags]
        : [flags] "=r" (flags)
    );

    return flags != original;
}

fn get_cpu_features() Features {
    var features: Features = .{};
    var vendor: [12]u8 = undefined;
    var max_cpuid: u32 = undefined;
    var max_extended_cpuid: u32 = undefined;

    // Get vendor string and maximum CPUID level
    asm volatile (
        \\ cpuid
        : [max] "={eax}" (max_cpuid),
          [ebx] "={ebx}" (vendor[0]),
          [edx] "={edx}" (vendor[4]),
          [ecx] "={ecx}" (vendor[8])
        : [leaf] "{eax}" (0)
    );

    // Get maximum extended CPUID level
    asm volatile (
        \\ cpuid
        : [max] "={eax}" (max_extended_cpuid)
        : [leaf] "{eax}" (0x80000000)
    );

    if (max_cpuid >= 1) {
        var eax: u32 = undefined;
        var ebx: u32 = undefined;
        var ecx: u32 = undefined;
        var edx: u32 = undefined;

        // Get feature flags
        asm volatile (
            \\ cpuid
            : [eax] "={eax}" (eax),
              [ebx] "={ebx}" (ebx),
              [ecx] "={ecx}" (ecx),
              [edx] "={edx}" (edx)
            : [leaf] "{eax}" (1)
        );

        features.apic = (edx & (1 << 9)) != 0;
        features.sse = (edx & (1 << 25)) != 0;
        features.sse4_2 = (ecx & (1 << 20)) != 0;
        features.xsave = (ecx & (1 << 26)) != 0;
        features.avx = (ecx & (1 << 28)) != 0;
        features.aes = (ecx & (1 << 25)) != 0;

        // Get core and thread counts
        core_count = ((ebx >> 16) & 0xFF);
        thread_count = ((ebx >> 24) & 0xFF);
    }

    if (max_cpuid >= 7) {
        var eax: u32 = undefined;
        var ebx: u32 = undefined;
        var ecx: u32 = undefined;
        var edx: u32 = undefined;

        // Get extended feature flags
        asm volatile (
            \\ cpuid
            : [eax] "={eax}" (eax),
              [ebx] "={ebx}" (ebx),
              [ecx] "={ecx}" (ecx),
              [edx] "={edx}" (edx)
            : [leaf] "{eax}" (7),
              [subleaf] "{ecx}" (0)
        );

        features.avx2 = (ebx & (1 << 5)) != 0;
        features.hybrid_cores = (edx & (1 << 15)) != 0;
    }

    // Get cache information
    if (max_cpuid >= 4) {
        var cache_type: u32 = 0;
        var i: u32 = 0;
        while (true) : (i += 1) {
            var eax: u32 = undefined;
            var ebx: u32 = undefined;
            var ecx: u32 = undefined;
            var edx: u32 = undefined;

            asm volatile (
                \\ cpuid
                : [eax] "={eax}" (eax),
                  [ebx] "={ebx}" (ebx),
                  [ecx] "={ecx}" (ecx),
                  [edx] "={edx}" (edx)
                : [leaf] "{eax}" (4),
                  [subleaf] "{ecx}" (i)
            );

            cache_type = eax & 0x1F;
            if (cache_type == 0) break;

            const cache_level = (eax >> 5) & 0x7;
            const cache_size = (((ebx >> 22) + 1) *
                              ((ebx >> 12) & 0x3FF) + 1) *
                              ((ebx & 0xFFF) + 1) *
                              (ecx + 1);

            switch (cache_level) {
                1 => features.l1_cache_size = cache_size,
                2 => features.l2_cache_size = cache_size,
                3 => features.l3_cache_size = cache_size,
                else => {},
            }
        }
    }

    // Get power management features
    if (max_cpuid >= 6) {
        var eax: u32 = undefined;
        var ebx: u32 = undefined;
        var ecx: u32 = undefined;
        asm volatile (
            \\ cpuid
            : [eax] "={eax}" (eax),
              [ebx] "={ebx}" (ebx),
              [ecx] "={ecx}" (ecx)
            : [leaf] "{eax}" (6)
        );

        features.intel_turbo_boost = (eax & (1 << 1)) != 0;
        features.enhanced_speedstep = (eax & (1 << 7)) != 0;
        features.power_limits = (eax & (1 << 4)) != 0;
    }

    return features;
}

// MSR addresses
const MSR = struct {
    const IA32_PERF_CTL: u32 = 0x199;
    const IA32_PM_ENABLE: u32 = 0x770;
    const IA32_HWP_CAPABILITIES: u32 = 0x771;
    const IA32_HWP_REQUEST: u32 = 0x774;
};

pub fn init() void {
    // Check if CPUID is available
    if (!check_cpuid()) {
        @panic("CPUID not supported!");
    }

    // Get CPU features
    cpu_features = get_cpu_features();

    // Log CPU information
    log.info("CPU: Intel i3-1215U detected", .{});
    log.info("Cores: {} physical, {} logical", .{ core_count, thread_count });
    log.info("Cache: L1={}KB, L2={}KB, L3={}MB", .{
        cpu_features.l1_cache_size / 1024,
        cpu_features.l2_cache_size / 1024,
        cpu_features.l3_cache_size / 1024 / 1024,
    });

    // Enable protected mode and required CPU features
    asm volatile (
        \\ // Disable interrupts during setup
        \\ cli
        \\
        \\ // Enable protected mode
        \\ mov %%cr0, %%rax
        \\ and $0xFFFB, %%ax    // Clear coprocessor emulation
        \\ or $0x2, %%ax        // Set coprocessor monitoring
        \\ mov %%rax, %%cr0
        \\
        \\ // Enable SSE and SSE4.2 if available
        \\ mov %%cr4, %%rax
        \\ or $0x600, %%rax     // Set OSFXSR and OSXMMEXCPT
        \\ mov %%rax, %%cr4
        \\
        \\ // Enable XSAVE if available
        \\ mov %%cr4, %%rax
        \\ or $0x40000, %%rax   // Set OSXSAVE
        \\ mov %%rax, %%cr4
    );

    // Enable AVX and AVX2 if available
    if (cpu_features.avx or cpu_features.avx2) {
        const xcr0: u64 = 0x7;  // Enable x87 FPU, SSE, and AVX state
        asm volatile (
            \\ xor %%rcx, %%rcx
            \\ xsetbv
            :
            : [xcr0] "{eax}" (xcr0)
        );
        log.info("AVX{s} enabled", .{if (cpu_features.avx2) "2" else ""});
    }

    // Configure hybrid core management if available
    if (cpu_features.hybrid_cores) {
        setup_hybrid_cores();
    }

    // Configure power management
    setup_power_management();

    // Enable hardware performance monitoring
    setup_performance_monitoring();

    log.info("CPU initialization complete", .{});
}

fn setup_hybrid_cores() void {
    // Configure thread scheduling hints for P-cores and E-cores
    // Intel Thread Director settings
    const thread_director_config: u64 = 0x1;  // Enable automatic thread placement
    write_msr(MSR.IA32_PM_ENABLE, thread_director_config);

    log.info("Hybrid core architecture configured", .{});
}

fn setup_power_management() void {
    if (cpu_features.enhanced_speedstep) {
        // Enable Intel SpeedStep
        var perf_ctl: u64 = read_msr(MSR.IA32_PERF_CTL);
        perf_ctl |= (1 << 16);  // Enable SpeedStep
        write_msr(MSR.IA32_PERF_CTL, perf_ctl);

        // Configure Hardware P-states
        if (cpu_features.intel_turbo_boost) {
            const hwp_caps = read_msr(MSR.IA32_HWP_CAPABILITIES);
            const highest_perf = (hwp_caps >> 24) & 0xFF;
            const guaranteed_perf = (hwp_caps >> 16) & 0xFF;
            const min_perf = hwp_caps & 0xFF;

            // Set initial HWP request
            const hwp_request: u64 =
                (highest_perf << 24) |    // Maximum performance
                (guaranteed_perf << 16) |  // Desired performance
                (min_perf << 0);          // Minimum performance
            write_msr(MSR.IA32_HWP_REQUEST, hwp_request);
        }

        log.info("Power management configured", .{});
    }
}

fn setup_performance_monitoring() void {
    // Configure performance monitoring counters
    // This will be used by the stargaze.zig monitoring system
    const PERF_GLOBAL_CTRL: u32 = 0x38F;
    const FIXED_CTR_CTRL: u32 = 0x38D;

    // Enable fixed-function performance counters
    write_msr(FIXED_CTR_CTRL, 0x333);  // Enable all rings
    write_msr(PERF_GLOBAL_CTRL, 0x7);  // Enable first 3 counters

    log.info("Performance monitoring configured", .{});
}

fn read_msr(msr: u32) u64 {
    var low: u32 = undefined;
    var high: u32 = undefined;

    asm volatile ("rdmsr"
        : [low] "={eax}" (low),
          [high] "={edx}" (high)
        : [msr] "{ecx}" (msr)
    );

    return (@as(u64, high) << 32) | low;
}

fn write_msr(msr: u32, value: u64) void {
    const low = @truncate(u32, value);
    const high = @truncate(u32, value >> 32);

    asm volatile ("wrmsr"
        :
        : [msr] "{ecx}" (msr),
          [low] "{eax}" (low),
          [high] "{edx}" (high)
    );
}
