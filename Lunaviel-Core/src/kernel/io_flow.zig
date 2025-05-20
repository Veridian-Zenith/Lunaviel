const std = @import("std");
const pulse = @import("pulse.zig");
const event_system = @import("event_system.zig");
const timing = @import("timing.zig");

pub const IOMode = enum {
    Synchronous,  // Direct, blocking operations
    Harmonic,     // Flow-controlled operations
    Resonant,     // High-priority, system-aligned operations
    Background,   // Low-priority, batched operations
};

pub const IORequest = struct {
    id: u64,
    mode: IOMode,
    priority: event_system.EventPriority,
    buffer: []u8,
    offset: u64,
    device_id: u16,
    completed: bool,
    resonance: f32,
    wave_phase: f32,
};

pub const IOFlow = struct {
    requests: std.ArrayList(IORequest),
    system_pulse: *pulse.SystemPulse,
    current_bandwidth: f32,    // MB/s
    bandwidth_limit: f32,      // MB/s
    flow_threshold: f32,       // Harmony threshold

    const MAX_CONCURRENT_IOS = 32;
    const BASE_BANDWIDTH = 3000.0; // 3 GB/s baseline for NVMe

    pub fn init(allocator: std.mem.Allocator, sys_pulse: *pulse.SystemPulse) IOFlow {
        return .{
            .requests = std.ArrayList(IORequest).init(allocator),
            .system_pulse = sys_pulse,
            .current_bandwidth = BASE_BANDWIDTH,
            .bandwidth_limit = BASE_BANDWIDTH,
            .flow_threshold = 0.7,
        };
    }

    pub fn queueRequest(self: *IOFlow, request: IORequest) !void {
        // Align request with system pulse
        var aligned_request = request;
        aligned_request.wave_phase = self.system_pulse.global_wave.phase;
        aligned_request.resonance = 1.0;

        try self.requests.append(aligned_request);

        // Notify system of new I/O
        timing.queueEvent(.{
            .type = .DiskIO,
            .priority = request.priority,
            .timestamp = timing.getCurrentTime(),
            .data = .{ .disk = .{
                .operation = .Write, // or .Read based on request
                .sector = request.offset / 512,
                .count = @intCast(u32, request.buffer.len / 512),
            }},
        });
    }

    pub fn processRequests(self: *IOFlow) void {
        // Update flow characteristics
        self.updateFlowMetrics();

        // Process requests based on system harmony
        var i: usize = 0;
        while (i < self.requests.items.len) {
            var request = &self.requests.items[i];

            if (self.canProcessRequest(request)) {
                self.executeRequest(request);
                if (request.completed) {
                    _ = self.requests.swapRemove(i);
                    continue;
                }
            }

            i += 1;
        }
    }

    fn updateFlowMetrics(self: *IOFlow) void {
        // Adjust bandwidth based on system pulse
        const pulse_factor = @intToFloat(f32, self.system_pulse.global_wave.amplitude) / 100.0;
        self.current_bandwidth = self.bandwidth_limit * pulse_factor;

        // Adjust flow threshold based on system resonance
        self.flow_threshold = 0.5 + (self.system_pulse.resonance * 0.3);
    }

    fn canProcessRequest(self: *IOFlow, request: *IORequest) bool {
        // Check if request aligns with current system phase
        const phase_diff = @fabs(request.wave_phase - self.system_pulse.global_wave.phase);

        return switch (request.mode) {
            .Synchronous => true, // Always process sync requests
            .Harmonic => phase_diff < std.math.pi / 2.0 and request.resonance > self.flow_threshold,
            .Resonant => self.system_pulse.resonance > 0.8,
            .Background => self.system_pulse.global_wave.amplitude < 70 and phase_diff < std.math.pi,
        };
    }

    fn executeRequest(self: *IOFlow, request: *IORequest) void {
        // Simulate I/O operation with flow control
        const bandwidth_per_request = self.current_bandwidth / @intToFloat(f32, MAX_CONCURRENT_IOS);
        const bytes_this_cycle = @floatToInt(usize, bandwidth_per_request * 1024 * 1024 / 1000); // bytes per ms

        // Update request progress
        const remaining = request.buffer.len;
        if (remaining <= bytes_this_cycle) {
            request.completed = true;
        }

        // Update request resonance based on I/O success
        request.resonance = std.math.min(
            1.0,
            request.resonance + 0.1 * self.system_pulse.resonance
        );
    }

    pub fn getCurrentLoad(self: IOFlow) f32 {
        return @intToFloat(f32, self.requests.items.len) / @intToFloat(f32, MAX_CONCURRENT_IOS);
    }

    pub fn adjustBandwidth(self: *IOFlow, system_load: f32) void {
        // Dynamically adjust bandwidth based on system load
        const load_factor = 1.0 - system_load;
        self.bandwidth_limit = BASE_BANDWIDTH * (0.5 + 0.5 * load_factor);
    }
};
