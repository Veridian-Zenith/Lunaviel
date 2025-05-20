const std = @import("std");
const event_system = @import("event_system.zig");
const timing = @import("timing.zig");

pub const PulseState = enum {
    Rising,  // System energy increasing
    Peak,    // Maximum system activity
    Falling, // Controlled decrease in activity
    Rest,    // Minimal activity for system stability
};

pub const PulseWave = struct {
    amplitude: u8,    // Current intensity (0-100)
    frequency: u32,   // Cycles per second
    phase: f32,      // Current position in cycle
    state: PulseState,
};

pub const SystemPulse = struct {
    core_waves: [6]PulseWave,  // One wave per CPU core
    global_wave: PulseWave,    // System-wide harmonics
    resonance: f32,            // System stability metric

    const MAX_AMPLITUDE: u8 = 100;
    const BASE_FREQUENCY: u32 = 1000; // 1KHz base rhythm

    pub fn init() SystemPulse {
        var pulse = SystemPulse{
            .core_waves = undefined,
            .global_wave = .{
                .amplitude = 50,
                .frequency = BASE_FREQUENCY,
                .phase = 0.0,
                .state = .Rising,
            },
            .resonance = 1.0,
        };

        // Initialize core waves with phase offsets
        for (pulse.core_waves) |*wave, i| {
            wave.* = .{
                .amplitude = 50,
                .frequency = BASE_FREQUENCY,
                .phase = @intToFloat(f32, i) * (2.0 * std.math.pi / 6.0),
                .state = .Rising,
            };
        }

        return pulse;
    }

    pub fn evolve(self: *SystemPulse) void {
        self.updateGlobalWave();
        self.evolveCoreWaves();
        self.harmonize();
    }

    fn evolveCoreWaves(self: *SystemPulse) void {
        for (self.core_waves) |*wave| {
            wave.phase += 2.0 * std.math.pi * @intToFloat(f32, wave.frequency) / BASE_FREQUENCY;
            if (wave.phase >= 2.0 * std.math.pi) {
                wave.phase -= 2.0 * std.math.pi;
            }

            // Update state and amplitude based on phase
            switch (wave.state) {
                .Rising => if (wave.amplitude < MAX_AMPLITUDE) {
                    wave.amplitude +%= 1;
                },
                .Falling => if (wave.amplitude > 0) {
                    wave.amplitude -%= 1;
                },
                .Peak => {
                    if (wave.amplitude > 90) wave.amplitude -%= 1
                    else if (wave.amplitude < 95) wave.amplitude +%= 1;
                },
                .Rest => if (wave.amplitude > 20) {
                    wave.amplitude -%= 2;
                },
            }
        }
    }

    fn updateGlobalWave(self: *SystemPulse) void {
        var total_amplitude: u32 = 0;
        for (self.core_waves) |wave| {
            total_amplitude += wave.amplitude;
        }

        self.global_wave.amplitude = @intCast(u8, total_amplitude / 6);
        self.global_wave.phase = self.calculateGlobalPhase();

        self.checkSystemHealth();
    }

    fn harmonize(self: *SystemPulse) void {
        var phase_variance: f32 = 0.0;
        const target_phase_diff = 2.0 * std.math.pi / 6.0;

        // Calculate phase variance
        for (self.core_waves) |wave, i| {
            const next_idx = (i + 1) % 6;
            const phase_diff = @fabs(wave.phase - self.core_waves[next_idx].phase);
            phase_variance += @fabs(phase_diff - target_phase_diff);
        }

        // Update resonance and adjust if needed
        self.resonance = 1.0 - (phase_variance / (2.0 * std.math.pi));
        if (self.resonance < 0.7) {
            self.reharmonize();
        }
    }

    fn reharmonize(self: *SystemPulse) void {
        for (self.core_waves) |*wave, i| {
            wave.phase = @intToFloat(f32, i) * (2.0 * std.math.pi / 6.0);
            wave.frequency = BASE_FREQUENCY + @floatToInt(u32, wave.phase * 10.0);
        }
    }

    fn calculateGlobalPhase(self: SystemPulse) f32 {
        var sum_sin: f32 = 0.0;
        var sum_cos: f32 = 0.0;

        for (self.core_waves) |wave| {
            sum_sin += @sin(wave.phase);
            sum_cos += @cos(wave.phase);
        }

        return std.math.atan2(f32, sum_sin, sum_cos);
    }

    fn checkSystemHealth(self: *SystemPulse) void {
        // Generate system events based on pulse state
        if (self.global_wave.amplitude > 90) {
            timing.queueEvent(.{
                .type = .SystemOverload,
                .priority = .High,
                .timestamp = timing.getCurrentTime(),
                .data = .{ .system = .{
                    .load = self.global_wave.amplitude,
                    .temperature = @floatToInt(u8, self.resonance * 100),
                }},
            });
        } else if (self.resonance < 0.5) {
            timing.queueEvent(.{
                .type = .HardwareError,
                .priority = .Critical,
                .timestamp = timing.getCurrentTime(),
                .data = .{ .hardware = .{
                    .device_id = 0,
                    .error_code = 0x1001, // Resonance loss
                }},
            });
        }
    }
};
