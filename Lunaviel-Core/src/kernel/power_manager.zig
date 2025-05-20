const std = @import("std");
const pulse = @import("../kernel/pulse.zig");
const perf = @import("../drivers/perf_monitor.zig");

pub const PowerState = enum {
    Performance, // Maximum frequency and voltage
    Balanced,    // Dynamic frequency scaling
    Efficient,   // Power-optimized
    UltraLow,    // Minimum frequency and voltage
};

pub const CoreState = struct {
    id: u8,
    current_freq: u32,
    current_voltage: f32,
    temperature: u8,
    power_state: PowerState,
    utilization: f32,
};

pub const PowerManager = struct {
    core_states: [6]CoreState,
    perf_monitor: *perf.PerformanceMonitor,
    system_pulse: *pulse.SystemPulse,

    // i3-1215U specific constants
    const BASE_FREQ: u32 = 1200;  // 1.2 GHz base
    const MAX_FREQ: u32 = 4400;   // 4.4 GHz max turbo
    const MIN_FREQ: u32 = 400;    // 400 MHz min
    const THERMAL_LIMIT: u8 = 85;  // 85°C thermal limit

    pub fn init(monitor: *perf.PerformanceMonitor, sys_pulse: *pulse.SystemPulse) PowerManager {
        var manager = PowerManager{
            .core_states = undefined,
            .perf_monitor = monitor,
            .system_pulse = sys_pulse,
        };

        // Initialize core states
        for (&manager.core_states) |*state, i| {
            state.* = .{
                .id = @intCast(u8, i),
                .current_freq = BASE_FREQ,
                .current_voltage = 0.8,
                .temperature = 0,
                .power_state = .Balanced,
                .utilization = 0.0,
            };
        }

        return manager;
    }

    pub fn updatePowerStates(self: *PowerManager) void {
        // Update core metrics
        for (&self.core_states) |*state| {
            const metrics = self.perf_monitor.core_metrics[state.id];
            state.temperature = metrics.temperature;
            state.current_freq = metrics.frequency;
            state.current_voltage = metrics.voltage;

            // Calculate utilization from pulse amplitude
            const wave = &self.system_pulse.core_waves[state.id];
            state.utilization = @intToFloat(f32, wave.amplitude) / 100.0;

            // Adjust power state based on conditions
            self.adjustCorePowerState(state);
        }

        // Apply thermal management if needed
        self.manageThermals();
    }

    fn adjustCorePowerState(self: *PowerManager, core: *CoreState) void {
        const util = core.utilization;
        const temp = core.temperature;

        // Determine appropriate power state
        const new_state = if (temp > THERMAL_LIMIT - 5) {
            PowerState.Efficient
        } else if (util > 0.8) {
            PowerState.Performance
        } else if (util > 0.4) {
            PowerState.Balanced
        } else if (util > 0.1) {
            PowerState.Efficient
        } else {
            PowerState.UltraLow
        };

        // Apply new power state if changed
        if (new_state != core.power_state) {
            core.power_state = new_state;
            self.applyPowerState(core);
        }
    }

    fn applyPowerState(self: *PowerManager, core: *CoreState) void {
        const target_freq = switch (core.power_state) {
            .Performance => MAX_FREQ,
            .Balanced => BASE_FREQ + @floatToInt(u32, core.utilization * @intToFloat(f32, MAX_FREQ - BASE_FREQ)),
            .Efficient => BASE_FREQ,
            .UltraLow => MIN_FREQ,
        };

        // Set frequency using MSR
        const target_ratio = target_freq / 100;
        asm volatile (
            \\wrmsr
            :
            : [reg] "{ecx}" (0x199),  // IA32_PERF_CTL
              [val] "{eax}" (target_ratio << 8),
              [val_high] "{edx}" (0)
        );
    }

    fn manageThermals(self: *PowerManager) void {
        var throttle_needed = false;

        // Check if any core is near thermal limit
        for (self.core_states) |state| {
            if (state.temperature > THERMAL_LIMIT) {
                throttle_needed = true;
                break;
            }
        }

        if (throttle_needed) {
            // Reduce frequency on all cores
            for (&self.core_states) |*state| {
                state.power_state = .Efficient;
                self.applyPowerState(state);
            }

            // Reduce system pulse amplitude
            self.system_pulse.global_wave.amplitude =
                std.math.max(20, self.system_pulse.global_wave.amplitude -% 10);
        }
    }

    pub fn getCurrentPowerDraw(self: PowerManager) f32 {
        var total_power: f32 = 0.0;

        for (self.core_states) |state| {
            const metrics = self.perf_monitor.core_metrics[state.id];
            total_power += metrics.power_consumption;
        }

        return total_power;
    }
};
