const std = @import("std");
const io_flow = @import("../kernel/io_flow.zig");
const pulse = @import("../kernel/pulse.zig");
const event_system = @import("../kernel/event_system.zig");
const hardware = @import("../kernel/hardware.zig");

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
    Recovery,
};

pub const DriverFlow = struct {
    resonance: f32,
    bandwidth: f32,
    latency: u32,
    error_rate: f32,
    wave_phase: f32,
};

pub const DriverCapability = struct {
    async_io: bool = false,
    dma_support: bool = false,
    interrupt_driven: bool = false,
    power_management: bool = false,
    hot_plug: bool = false,
};

pub const Driver = struct {
    id: u16,
    type: DriverType,
    state: DriverState,
    flow: DriverFlow,
    io_queue: *io_flow.IOFlow,
    capabilities: DriverCapability,
    resources: std.ArrayList(hardware.Resource),

    const HarmonizationThreshold = struct {
        min_resonance: f32 = 0.3,
        target_resonance: f32 = 0.8,
        recovery_threshold: f32 = 0.5,
    };

    pub fn init(id: u16, driver_type: DriverType, io: *io_flow.IOFlow) !Driver {
        return .{
            .id = id,
            .type = driver_type,
            .state = .Uninitialized,
            .flow = .{
                .resonance = 1.0,
                .bandwidth = 0.0,
                .latency = 0,
                .error_rate = 0.0,
                .wave_phase = 0.0,
            },
            .io_queue = io,
            .capabilities = .{},
            .resources = std.ArrayList(hardware.Resource).init(std.heap.page_allocator),
        };
    }

    pub fn deinit(self: *Driver) void {
        self.resources.deinit();
    }

    pub fn submitIO(self: *Driver, buffer: []u8, offset: u64, priority: event_system.EventPriority) !void {
        if (self.state == .Error or self.state == .Suspended) {
            return error.DriverUnavailable;
        }

        const mode = if (self.flow.resonance > HarmonizationThreshold.target_resonance)
            io_flow.IOMode.Resonant
        else if (self.flow.resonance > HarmonizationThreshold.min_resonance)
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
            .wave_phase = self.flow.wave_phase,
        });
    }

    pub fn updateFlow(self: *Driver, system_pulse: *pulse.SystemPulse) void {
        const load = self.io_queue.getCurrentLoad();

        // Update resonance based on I/O performance
        if (load > 0.8) {
            self.flow.resonance = std.math.max(0.0, self.flow.resonance - 0.1);
        } else if (load < 0.3) {
            self.flow.resonance = std.math.min(1.0, self.flow.resonance + 0.05);
        }

        // Adjust bandwidth based on system pulse
        self.flow.bandwidth = @intToFloat(f32, system_pulse.global_wave.amplitude) *
            self.io_queue.current_bandwidth / 100.0;

        // Update driver state based on health metrics
        self.updateState();

        // Harmonize with system wave
        self.flow.wave_phase = system_pulse.global_wave.phase;
    }

    pub fn updateState(self: *Driver) void {
        const old_state = self.state;

        if (self.flow.error_rate > 0.1) {
            self.state = .Error;
        } else if (self.flow.resonance < HarmonizationThreshold.min_resonance) {
            self.state = .Suspended;
        } else if (self.flow.resonance < HarmonizationThreshold.recovery_threshold) {
            self.state = .Recovery;
        } else {
            self.state = .Active;
        }

        if (old_state != self.state) {
            self.notifyStateChange();
        }
    }

    fn notifyStateChange(self: *Driver) void {
        event_system.queueEvent(.{
            .type = .DriverStateChanged,
            .priority = .High,
            .timestamp = std.time.milliTimestamp(),
            .data = .{
                .driver_state = .{
                    .id = self.id,
                    .old_state = @enumToInt(self.state),
                    .new_state = @enumToInt(self.state),
                    .resonance = self.flow.resonance,
                },
            },
        }) catch {};
    }

    pub fn addResource(self: *Driver, res: hardware.Resource) !void {
        try self.resources.append(res);
    }
};

fn generateRequestId() u64 {
    static var next_id: u64 = 0;
    next_id += 1;
    return next_id;
}
