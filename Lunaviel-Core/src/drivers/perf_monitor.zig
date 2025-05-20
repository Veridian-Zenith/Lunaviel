const std = @import("std");

// Intel Performance Monitoring Events for i3-1215U (Alder Lake)
pub const PerfEvent = enum(u32) {
    UnhaltedCoreCycles = 0x003C,
    InstructionsRetired = 0x00C0,
    LLCMisses = 0x2E01,         // Last Level Cache misses
    BranchMispredicts = 0x00C5,
    DTLBMisses = 0x0849,        // Data TLB misses
    UopsCacheHit = 0x01D2,      // Micro-ops cache hits
};

pub const PerfCounter = struct {
    event: PerfEvent,
    counter: u32,
    value: u64,
};

pub const CoreMetrics = struct {
    temperature: u8,
    frequency: u32,
    voltage: f32,
    power_consumption: f32,
};

pub const PerformanceMonitor = struct {
    counters: [4]PerfCounter,
    core_metrics: [6]CoreMetrics,
    last_sample_time: u64,

    pub fn init() PerformanceMonitor {
        return .{
            .counters = undefined,
            .core_metrics = undefined,
            .last_sample_time = 0,
        };
    }

    pub fn setupCounter(self: *PerformanceMonitor, index: u32, event: PerfEvent) void {
        if (index >= 4) return; // Only 4 PMC registers available

        // Setup performance counter
        const event_sel: u64 = @enumToInt(event) | (1 << 16) | (1 << 17) | (1 << 22);

        asm volatile (
            \\wrmsr
            :
            : [reg] "{ecx}" (0x186 + index),  // PERFEVTSEL0 + index
              [val] "{eax}" (@truncate(u32, event_sel)),
              [val_high] "{edx}" (@truncate(u32, event_sel >> 32))
        );

        self.counters[index] = .{
            .event = event,
            .counter = index,
            .value = 0,
        };
    }

    pub fn startCounting(self: *PerformanceMonitor) void {
        // Enable all configured counters
        asm volatile (
            \\wrmsr
            :
            : [reg] "{ecx}" (0x38F),  // IA32_PERF_GLOBAL_CTRL
              [val] "{eax}" (0x0F),    // Enable counters 0-3
              [val_high] "{edx}" (0)
        );

        self.last_sample_time = self.readTSC();
    }

    pub fn stopCounting(self: *PerformanceMonitor) void {
        asm volatile (
            \\wrmsr
            :
            : [reg] "{ecx}" (0x38F),  // IA32_PERF_GLOBAL_CTRL
              [val] "{eax}" (0),      // Disable all counters
              [val_high] "{edx}" (0)
        );
    }

    pub fn readCounter(self: *PerformanceMonitor, index: u32) u64 {
        var low: u32 = undefined;
        var high: u32 = undefined;

        asm volatile (
            \\rdmsr
            : [low] "={eax}" (low),
              [high] "={edx}" (high)
            : [reg] "{ecx}" (0xC1 + index)  // PERFCTR0 + index
        );

        return (@as(u64, high) << 32) | low;
    }

    pub fn sampleAllCounters(self: *PerformanceMonitor) void {
        const current_time = self.readTSC();
        const time_delta = current_time - self.last_sample_time;
        self.last_sample_time = current_time;

        for (self.counters) |*counter| {
            const new_value = self.readCounter(counter.counter);
            counter.value = new_value;
        }

        self.updateCoreMetrics(time_delta);
    }

    fn updateCoreMetrics(self: *PerformanceMonitor, time_delta: u64) void {
        for (self.core_metrics) |*metrics, core| {
            metrics.* = .{
                .temperature = self.readCoreTemperature(@intCast(u8, core)),
                .frequency = self.readCoreFrequency(@intCast(u8, core)),
                .voltage = self.readCoreVoltage(@intCast(u8, core)),
                .power_consumption = self.calculatePowerConsumption(
                    metrics.temperature,
                    metrics.frequency,
                    metrics.voltage,
                    time_delta
                ),
            };
        }
    }

    fn readTSC() u64 {
        return asm volatile (
            \\rdtsc
            : [ret] "={eax}" (-> u64)
        );
    }

    fn readCoreTemperature(self: *PerformanceMonitor, core: u8) u8 {
        // Read temperature using MSR_TEMPERATURE_TARGET
        var low: u32 = undefined;
        var high: u32 = undefined;

        asm volatile (
            \\rdmsr
            : [low] "={eax}" (low),
              [high] "={edx}" (high)
            : [reg] "{ecx}" (0x1A2)  // MSR_TEMPERATURE_TARGET
        );

        const target_temp = (high >> 16) & 0xFF;
        const offset = (low >> 24) & 0xFF;
        return @intCast(u8, target_temp - offset);
    }

    fn readCoreFrequency(self: *PerformanceMonitor, core: u8) u32 {
        _ = core;
        // Read current frequency using IA32_PERF_STATUS
        var low: u32 = undefined;
        var high: u32 = undefined;

        asm volatile (
            \\rdmsr
            : [low] "={eax}" (low),
              [high] "={edx}" (high)
            : [reg] "{ecx}" (0x198)  // IA32_PERF_STATUS
        );

        const current_ratio = (low >> 8) & 0xFF;
        return current_ratio * 100; // Base frequency multiplier
    }

    fn readCoreVoltage(self: *PerformanceMonitor, core: u8) f32 {
        _ = core;
        // Read voltage using MSR_RAPL_POWER_UNIT
        var low: u32 = undefined;
        var high: u32 = undefined;

        asm volatile (
            \\rdmsr
            : [low] "={eax}" (low),
              [high] "={edx}" (high)
            : [reg] "{ecx}" (0x606)  // MSR_RAPL_POWER_UNIT
        );

        const voltage_unit = @intToFloat(f32, (low >> 8) & 0x1F) / 1000.0;
        return voltage_unit;
    }

    fn calculatePowerConsumption(
        self: *PerformanceMonitor,
        temperature: u8,
        frequency: u32,
        voltage: f32,
        time_delta: u64,
    ) f32 {
        // Basic power calculation using P = C * V² * f
        const capacitance: f32 = 0.000001; // Approximate CPU capacitance
        const voltage_squared = voltage * voltage;
        const freq_ghz = @intToFloat(f32, frequency) / 1000.0;

        var power = capacitance * voltage_squared * freq_ghz;

        // Adjust for temperature effects
        const temp_factor = 1.0 + (@intToFloat(f32, temperature) - 50.0) / 100.0;
        power *= temp_factor;

        return power;
    }
};
