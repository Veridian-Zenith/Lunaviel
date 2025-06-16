const std = @import("std");
const driver = @import("driver.zig");
const io_flow = @import("../kernel/io_flow.zig");
const event_system = @import("../kernel/event_system.zig");
const pulse = @import("../kernel/pulse.zig");
const resource = @import("../kernel/hardware.zig");

pub const DriverInfo = struct {
    id: u16,
    type: driver.DriverType,
    name: []const u8,
    version: u32,
    capabilities: u32,
    resources: []resource.Resource,
};

pub const DriverRegistry = struct {
    const MAX_DRIVERS = 64;

    drivers: std.AutoHashMap(u16, *driver.Driver),
    driver_info: std.AutoHashMap(u16, DriverInfo),
    system_pulse: *pulse.SystemPulse,
    allocator: *std.mem.Allocator,

    pub fn init(allocator: *std.mem.Allocator, sys_pulse: *pulse.SystemPulse) !DriverRegistry {
        return DriverRegistry{
            .drivers = std.AutoHashMap(u16, *driver.Driver).init(allocator),
            .driver_info = std.AutoHashMap(u16, DriverInfo).init(allocator),
            .system_pulse = sys_pulse,
            .allocator = allocator,
        };
    }

    pub fn registerDriver(self: *DriverRegistry, drv: *driver.Driver, info: DriverInfo) !void {
        if (self.drivers.count() >= MAX_DRIVERS) {
            return error.TooManyDrivers;
        }

        try self.drivers.put(info.id, drv);
        try self.driver_info.put(info.id, info);

        // Register driver's resources
        for (info.resources) |res| {
            resource.registerResource(res.id, 0, res.type);
        }

        // Initialize driver wave state
        drv.flow.resonance = 1.0;
        self.system_pulse.registerDriverWave(info.id, &drv.flow);

        try event_system.queueEvent(.{
            .type = .DriverRegistered,
            .priority = .Normal,
            .timestamp = std.time.milliTimestamp(),
            .data = .{
                .driver_event = .{
                    .id = info.id,
                    .type = @enumToInt(info.type),
                },
            },
        });
    }

    pub fn unregisterDriver(self: *DriverRegistry, id: u16) void {
        if (self.drivers.remove(id)) |drv| {
            self.system_pulse.unregisterDriverWave(id);

            if (self.driver_info.get(id)) |info| {
                for (info.resources) |res| {
                    // Clean up resources
                    resource.unregisterResource(res.id);
                }
            }

            _ = self.driver_info.remove(id);

            event_system.queueEvent(.{
                .type = .DriverUnregistered,
                .priority = .Normal,
                .timestamp = std.time.milliTimestamp(),
                .data = .{
                    .driver_event = .{
                        .id = id,
                        .type = @enumToInt(drv.type),
                    },
                },
            }) catch {};
        }
    }

    pub fn getDriver(self: *DriverRegistry, id: u16) ?*driver.Driver {
        return self.drivers.get(id);
    }

    pub fn getDriverInfo(self: *DriverRegistry, id: u16) ?DriverInfo {
        return self.driver_info.get(id);
    }

    pub fn listDrivers(self: *DriverRegistry) []const DriverInfo {
        var drivers = std.ArrayList(DriverInfo).init(self.allocator);
        var it = self.driver_info.iterator();
        while (it.next()) |entry| {
            drivers.append(entry.value) catch continue;
        }
        return drivers.items;
    }

    pub fn findDriverByType(self: *DriverRegistry, driver_type: driver.DriverType) ?*driver.Driver {
        var it = self.drivers.iterator();
        while (it.next()) |entry| {
            if (entry.value.type == driver_type) {
                return entry.value;
            }
        }
        return null;
    }

    pub fn updateDriverStates(self: *DriverRegistry) void {
        var it = self.drivers.iterator();
        while (it.next()) |entry| {
            entry.value.updateFlow(self.system_pulse);
        }
    }
};
