const std = @import("std");

pub const ResourceType = enum {
    CPU_Core,
    Memory_L1,
    Memory_L2,
    Memory_L3,
    Memory_Main,
    IO_Device,
};

pub const ResourceState = struct {
    type: ResourceType,
    utilization: u8, // 0-100%
    temperature: ?u8, // CPU cores only
    power_state: enum {
        Active,
        Low_Power,
        Sleep,
    },
};

// Configuration for i3-1215U
pub const CPU_CORES: usize = 6;
pub const CPU_THREADS: usize = 8;
pub const L1_CACHE_PER_CORE: usize = 224 * 1024 / CPU_CORES; // L1 data cache per core
pub const L2_CACHE_TOTAL: usize = 4.5 * 1024 * 1024;
pub const L3_CACHE_TOTAL: usize = 10 * 1024 * 1024;

pub const ResourceManager = struct {
    core_states: [CPU_CORES]ResourceState,
    memory_states: struct {
        l1: ResourceState,
        l2: ResourceState,
        l3: ResourceState,
        main: ResourceState,
    },

    pub fn init() ResourceManager {
        var manager = ResourceManager{
            .core_states = undefined,
            .memory_states = .{
                .l1 = .{
                    .type = .Memory_L1,
                    .utilization = 0,
                    .temperature = null,
                    .power_state = .Active,
                },
                .l2 = .{
                    .type = .Memory_L2,
                    .utilization = 0,
                    .temperature = null,
                    .power_state = .Active,
                },
                .l3 = .{
                    .type = .Memory_L3,
                    .utilization = 0,
                    .temperature = null,
                    .power_state = .Active,
                },
                .main = .{
                    .type = .Memory_Main,
                    .utilization = 0,
                    .temperature = null,
                    .power_state = .Active,
                },
            },
        };

        // Initialize core states
        for (manager.core_states) |*state, i| {
            state.* = .{
                .type = .CPU_Core,
                .utilization = 0,
                .temperature = 0,
                .power_state = .Active,
            };
        }

        return manager;
    }

    pub fn optimizeResources(self: *ResourceManager) void {
        var total_utilization: usize = 0;

        // Calculate total CPU utilization
        for (self.core_states) |state| {
            total_utilization += state.utilization;
        }

        const avg_utilization = total_utilization / CPU_CORES;

        // Implement power states based on utilization
        for (self.core_states) |*state| {
            if (state.utilization < 20) {
                state.power_state = .Low_Power;
            } else if (state.utilization > 80) {
                state.power_state = .Active;
            }
        }

        // Memory hierarchy optimization
        if (avg_utilization > 70) {
            // High load - ensure all caches are active
            self.memory_states.l1.power_state = .Active;
            self.memory_states.l2.power_state = .Active;
            self.memory_states.l3.power_state = .Active;
        } else if (avg_utilization < 30) {
            // Low load - power save on higher caches
            self.memory_states.l2.power_state = .Low_Power;
            self.memory_states.l3.power_state = .Low_Power;
        }
    }

    pub fn allocateCore(self: *ResourceManager) ?usize {
        for (self.core_states) |state, i| {
            if (state.utilization < 70) {
                return i;
            }
        }
        return null;
    }
};
