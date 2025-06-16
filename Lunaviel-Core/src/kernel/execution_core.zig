const std = @import("std");
const scheduler = @import("../process/scheduler.zig");
const optimizer = @import("../process/optimizer.zig");
const pulse = @import("pulse.zig");
const timing = @import("timing.zig");
const event_system = @import("event_system.zig");
const perf = @import("../drivers/perf_monitor.zig");
const power = @import("power_manager.zig");
const syscall_table = @import("syscall_table.zig");
const fs = @import("../fs/hookt_fs.zig");
const network = @import("../net/stack.zig");
const cache_manager = @import("../cpu/cache_manager.zig");
const cpu_init = @import("../cpu/cpu_init.zig");
const driver_registry = @import("../drivers/driver_registry.zig");

pub const ExecutionCore = struct {
    scheduler: *scheduler.Scheduler,
    optimizer: optimizer.FlowOptimizer,
    system_pulse: *pulse.SystemPulse,
    perf_monitor: perf.PerformanceMonitor,
    power_manager: power.PowerManager,
    cache_mgr: *cache_manager.CacheManager,
    filesystem: ?*fs.HooktFS,
    network_stack: ?*network.NetworkStack,
    driver_registry: *driver_registry.DriverRegistry,
    last_optimization: u64,

    const OPTIMIZATION_INTERVAL = 1000; // 1 second

    pub fn init(
        sched: *scheduler.Scheduler,
        sys_pulse: *pulse.SystemPulse,
        cache_mgr: *cache_manager.CacheManager,
    ) !ExecutionCore {
        var registry = try driver_registry.DriverRegistry.init(std.heap.page_allocator, sys_pulse);

        return ExecutionCore{
            .scheduler = sched,
            .optimizer = optimizer.FlowOptimizer.init(),
            .system_pulse = sys_pulse,
            .perf_monitor = try perf.PerformanceMonitor.init(),
            .power_manager = try power.PowerManager.init(),
            .cache_mgr = cache_mgr,
            .filesystem = null,
            .network_stack = null,
            .driver_registry = &registry,
            .last_optimization = 0,
        };
    }

    pub fn execute(self: *ExecutionCore) void {
        const current_time = timing.getCurrentTime();

        // Update system state
        self.system_pulse.evolve();
        self.perf_monitor.update();

        // Process scheduled tasks
        self.scheduler.schedule();

        // Update driver states
        self.driver_registry.updateDriverStates();

        // Handle pending events
        self.handleEvents();

        // Periodic optimization
        if (current_time - self.last_optimization >= OPTIMIZATION_INTERVAL) {
            self.optimizeExecution();
            self.last_optimization = current_time;
        }

        // Maintain system harmony
        self.harmonizeSystem();
    }

    pub fn harmonizeSystem(self: *ExecutionCore) void {
        // First harmonize filesystem if available
        self.harmonizeFilesystem();

        // Adjust system parameters based on current state
        const system_load = self.perf_monitor.getSystemLoad();
        if (system_load > 85) {
            self.handleOverload(.{
                .type = .SystemOverload,
                .priority = .High,
                .timestamp = timing.getCurrentTime(),
                .data = .{ .system = .{
                    .load = system_load,
                    .temperature = self.perf_monitor.core_metrics[0].temperature,
                }},
            });
        }

        // Update power states based on load
        self.power_manager.updatePowerStates();

        // Optimize cache usage
        self.cache_mgr.optimizeCacheUsage();

        // Update network stack if available
        if (self.network_stack) |net| {
            net.processNetworkEvents() catch |err| {
                // Log network error
                timing.queueEvent(.{
                    .type = .NetworkError,
                    .priority = .High,
                    .timestamp = timing.getCurrentTime(),
                    .data = .{
                        .network_error = .{
                            .error_code = @enumToInt(err),
                            .operation = "process_events",
                        },
                    },
                });
            };
        }
    }

    // ... rest of ExecutionCore implementation remains the same ...
};
