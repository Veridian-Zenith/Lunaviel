const std = @import("std");
const log = @import("oracle.zig");

// Performance monitoring events for Intel processors
const PerfEvent = enum(u32) {
    // Core events
    Instructions = 0x00C0,
    Cycles = 0x003C,
    BranchMisses = 0x00C5,
    CacheMisses = 0x0008,

    // Memory events
    MemoryLoads = 0x0081,
    MemoryStores = 0x0082,

    // Thread events
    ContextSwitches = 0x00CD,
    ThreadMigrations = 0x00CE,
};

// Performance counter configuration
const PerfConfig = struct {
    event: PerfEvent,
    user_mode: bool = true,
    kernel_mode: bool = true,
    edge_detect: bool = false,
    pin_control: bool = false,
    interrupt: bool = false,
    enabled: bool = true,
};

// CPU performance state
const PState = struct {
    frequency: u32,
    voltage: u32,
    power: u32,
    temperature: i32,
};

// Performance monitoring data structure
const PerfData = struct {
    timestamp: u64,
    counters: [4]u64,
    p_state: PState,
};

// Circular buffer for performance data
const PERF_BUFFER_SIZE = 1024;
var perf_buffer: [PERF_BUFFER_SIZE]PerfData = undefined;
var perf_buffer_pos: usize = 0;

// MSR constants
const MSR = struct {
    const IA32_PERF_GLOBAL_CTRL = 0x38F;
    const IA32_PERFEVTSEL0 = 0x186;
    const IA32_PMC0 = 0xC1;
    const IA32_MPERF = 0xE7;
    const IA32_APERF = 0xE8;
    const IA32_THERM_STATUS = 0x19C;
    const MSR_PLATFORM_INFO = 0xCE;
};

// Initialize performance monitoring
pub fn init() void {
    // Disable all performance counters
    write_msr(MSR.IA32_PERF_GLOBAL_CTRL, 0);

    // Configure default events
    setup_perf_event(0, .{
        .event = .Instructions,
        .user_mode = true,
        .kernel_mode = true,
    });

    setup_perf_event(1, .{
        .event = .Cycles,
        .user_mode = true,
        .kernel_mode = true,
    });

    setup_perf_event(2, .{
        .event = .BranchMisses,
        .user_mode = true,
        .kernel_mode = true,
    });

    setup_perf_event(3, .{
        .event = .CacheMisses,
        .user_mode = true,
        .kernel_mode = true,
    });

    // Enable configured counters
    write_msr(MSR.IA32_PERF_GLOBAL_CTRL, 0xF);

    log.info("Performance monitoring initialized", .{});
}

// Configure a performance monitoring event
fn setup_perf_event(counter: u32, config: PerfConfig) void {
    var value: u64 = 0;

    // Set event code and umask
    value |= @enumToInt(config.event) & 0xFFFF;

    // Set flags
    if (config.user_mode) value |= (1 << 16);
    if (config.kernel_mode) value |= (1 << 17);
    if (config.edge_detect) value |= (1 << 18);
    if (config.pin_control) value |= (1 << 19);
    if (config.interrupt) value |= (1 << 20);
    if (config.enabled) value |= (1 << 22);

    write_msr(MSR.IA32_PERFEVTSEL0 + counter, value);
}

// Read performance counters
pub fn read_counters() [4]u64 {
    var counters: [4]u64 = undefined;

    for (0..4) |i| {
        counters[i] = read_msr(MSR.IA32_PMC0 + i);
    }

    return counters;
}

// Get current P-state information
pub fn get_p_state() PState {
    const mperf = read_msr(MSR.IA32_MPERF);
    const aperf = read_msr(MSR.IA32_APERF);
    const therm_status = read_msr(MSR.IA32_THERM_STATUS);
    const platform_info = read_msr(MSR.MSR_PLATFORM_INFO);

    // Calculate actual frequency
    const base_freq = ((platform_info >> 8) & 0xFF) * 100;
    const current_freq = @floatToInt(u32, @intToFloat(f64, base_freq) * @intToFloat(f64, aperf) / @intToFloat(f64, mperf));

    // Get temperature (in degrees Celsius)
    const temp_target = @intCast(i32, (therm_status >> 16) & 0x7F);
    const temp_offset = @intCast(i32, (therm_status >> 23) & 0x7F);
    const current_temp = temp_target - temp_offset;

    return PState{
        .frequency = current_freq,
        .voltage = 0, // TODO: Implement voltage reading
        .power = 0,   // TODO: Implement power reading
        .temperature = current_temp,
    };
}

// Sample performance data
pub fn sample() void {
    const perf_data = PerfData{
        .timestamp = get_timestamp(),
        .counters = read_counters(),
        .p_state = get_p_state(),
    };

    perf_buffer[perf_buffer_pos] = perf_data;
    perf_buffer_pos = (perf_buffer_pos + 1) % PERF_BUFFER_SIZE;
}

// Get performance data for analysis
pub fn get_perf_data() []const PerfData {
    return perf_buffer[0..perf_buffer_pos];
}

// Reset performance counters
pub fn reset_counters() void {
    for (0..4) |i| {
        write_msr(MSR.IA32_PMC0 + i, 0);
    }
}

// Helper functions for MSR access
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

fn get_timestamp() u64 {
    var timestamp: u64 = undefined;
    asm volatile ("rdtsc"
        : [ret] "={eax}" (timestamp)
    );
    return timestamp;
}

// Analysis functions
pub fn calculate_ipc() f64 {
    const data = get_perf_data();
    if (data.len < 2) return 0;

    const instructions = data[data.len - 1].counters[0] - data[0].counters[0];
    const cycles = data[data.len - 1].counters[1] - data[0].counters[1];

    return @intToFloat(f64, instructions) / @intToFloat(f64, cycles);
}

pub fn calculate_branch_miss_rate() f64 {
    const data = get_perf_data();
    if (data.len < 2) return 0;

    const branch_misses = data[data.len - 1].counters[2] - data[0].counters[2];
    const instructions = data[data.len - 1].counters[0] - data[0].counters[0];

    return @intToFloat(f64, branch_misses) / @intToFloat(f64, instructions) * 100;
}

pub fn calculate_cache_miss_rate() f64 {
    const data = get_perf_data();
    if (data.len < 2) return 0;

    const cache_misses = data[data.len - 1].counters[3] - data[0].counters[3];
    const instructions = data[data.len - 1].counters[0] - data[0].counters[0];

    return @intToFloat(f64, cache_misses) / @intToFloat(f64, instructions) * 100;
}
