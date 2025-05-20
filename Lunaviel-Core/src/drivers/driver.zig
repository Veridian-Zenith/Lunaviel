const std = @import("std");
const io_flow = @import("../kernel/io_flow.zig");
const pulse = @import("../kernel/pulse.zig");
const event_system = @import("../kernel/event_system.zig");

pub const DriverType = enum {
    Storage,
    Network,
    Input,
    Display,
    System,
};

pub const DriverState = enum {
    Uninitialized,
    Active,
    Suspended,
    Error,
};

pub const DriverFlow = struct {
    resonance: f32,
    bandwidth: f32,
    latency: u32,
    error_rate: f32,
};

pub const Driver = struct {
    id: u16,
    type: DriverType,
    state: DriverState,
    flow: DriverFlow,
    io_queue: *io_flow.IOFlow,

    pub fn init(id: u16, driver_type: DriverType, io: *io_flow.IOFlow) Driver {
        return .{
            .id = id,
            .type = driver_type,
            .state = .Uninitialized,
            .flow = .{
                .resonance = 1.0,
                .bandwidth = 0.0,
                .latency = 0,
                .error_rate = 0.0,
            },
            .io_queue = io,
        };
    }

    pub fn submitIO(self: *Driver, buffer: []u8, offset: u64, priority: event_system.EventPriority) !void {
        // Create I/O request with appropriate mode based on driver state
        const mode = if (self.flow.resonance > 0.8)
            io_flow.IOMode.Resonant
        else if (self.flow.resonance > 0.5)
            io_flow.IOMode.Harmonic
        else
            io_flow.IOMode.Background;

        try self.io_queue.queueRequest(.{
            .id = generateRequestId(),
            .mode = mode,
            .priority = priority,
            .buffer = buffer,
            .offset = offset,
            .device_id = self.id,
            .completed = false,
            .resonance = self.flow.resonance,
            .wave_phase = 0.0, // Will be set by IO system
        });
    }

    pub fn updateFlow(self: *Driver, system_pulse: *pulse.SystemPulse) void {
        // Update driver flow characteristics based on system state
        const load = self.io_queue.getCurrentLoad();

        // Adjust resonance based on I/O performance
        if (load > 0.8) {
            self.flow.resonance = std.math.max(0.0, self.flow.resonance - 0.1);
        } else if (load < 0.3) {
            self.flow.resonance = std.math.min(1.0, self.flow.resonance + 0.05);
        }

        // Adjust bandwidth based on system pulse
        self.flow.bandwidth = @intToFloat(f32, system_pulse.global_wave.amplitude) *
            self.io_queue.current_bandwidth / 100.0;

        // Update driver state if needed
        if (self.flow.error_rate > 0.1) {
            self.state = .Error;
        } else if (self.flow.resonance < 0.3) {
            self.state = .Suspended;
        } else {
            self.state = .Active;
        }
    }
};

fn generateRequestId() u64 {
    static var next_id: u64 = 0;
    next_id += 1;
    return next_id;
}

pub fn initDrivers() void {
    whisper(0x60, 0x01); // Example hardware interaction (to be refined)
}
