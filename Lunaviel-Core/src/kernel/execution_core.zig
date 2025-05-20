const std = @import("std");
const scheduler = @import("../process/scheduler.zig");
const optimizer = @import("../process/optimizer.zig");
const pulse = @import("pulse.zig");
const timing = @import("timing.zig");
const event_system = @import("event_system.zig");
const perf = @import("../drivers/perf_monitor.zig");
const power = @import("power_manager.zig");
const syscall_table = @import("syscall_table.zig");
const fs = @import("../fs/controller.zig");
const network = @import("../net/stack.zig");

pub const ExecutionCore = struct {
    scheduler: *scheduler.Scheduler,
    optimizer: optimizer.FlowOptimizer,
    system_pulse: *pulse.SystemPulse,
    perf_monitor: perf.PerformanceMonitor,
    power_manager: power.PowerManager,
    fs_controller: fs.FSController,
    network_stack: network.NetworkStack,
    last_optimization: u64,
    active_cores: u8,

    const OPTIMIZATION_INTERVAL: u64 = 1000; // Optimize every 1000 ticks

    pub fn init(sched: *scheduler.Scheduler, sys_pulse: *pulse.SystemPulse) ExecutionCore {
        var core = ExecutionCore{
            .scheduler = sched,
            .optimizer = optimizer.FlowOptimizer.init(),
            .system_pulse = sys_pulse,
            .perf_monitor = perf.PerformanceMonitor.init(),
            .power_manager = undefined,
            .fs_controller = fs.FSController.init(allocator, sys_pulse),
            .network_stack = network.NetworkStack.init(allocator, sys_pulse),
            .last_optimization = 0,
            .active_cores = 6, // Based on i3-1215U
        };

        // Initialize performance monitoring
        core.perf_monitor.setupCounter(0, .UnhaltedCoreCycles);
        core.perf_monitor.setupCounter(1, .InstructionsRetired);
        core.perf_monitor.setupCounter(2, .LLCMisses);
        core.perf_monitor.setupCounter(3, .DTLBMisses);
        core.perf_monitor.startCounting();

        // Initialize power management
        core.power_manager = power.PowerManager.init(&core.perf_monitor, sys_pulse);

        return core;
    }

    pub fn execute(self: *ExecutionCore) void {
        const current_time = timing.getCurrentTime();

        // Evolve system state
        self.system_pulse.evolve();

        // Update power states
        self.power_manager.updatePowerStates();

        // Handle scheduled tasks
        self.scheduler.schedule();

        // Process network events
        self.network_stack.processNetworkEvents() catch |err| {
            // Log network error
            timing.queueEvent(.{
                .type = .NetworkError,
                .priority = .High,
                .timestamp = current_time,
                .data = .{
                    .network_error = .{
                        .error_code = @enumToInt(err),
                        .operation = "process_events",
                    },
                },
            });
        };

        // Periodic optimization
        if (current_time - self.last_optimization >= OPTIMIZATION_INTERVAL) {
            self.optimizeExecution();
            self.last_optimization = current_time;
        }

        // Process system events
        self.handleEvents();

        // Maintain system harmony
        self.harmonizeSystem();

        // Synchronize filesystems
        self.fs_controller.sync() catch |err| {
            // Log filesystem sync error
            timing.queueEvent(.{
                .type = .FSError,
                .priority = .High,
                .timestamp = current_time,
                .data = .{
                    .fs_error = .{
                        .error_code = @enumToInt(err),
                        .operation = "sync",
                    },
                },
            });
        };
    }

    fn optimizeExecution(self: *ExecutionCore) void {
        // Sample performance counters
        self.perf_monitor.sampleAllCounters();

        // Optimize each active task
        if (self.scheduler.current_task) |task| {
            self.optimizer.optimizeTask(task);
        }

        // Balance core load and power states
        self.balanceCoreLoad();

        // Check system health
        const power_draw = self.power_manager.getCurrentPowerDraw();
        if (power_draw > 15.0) { // TDP threshold for i3-1215U
            self.handlePowerLimit();
        }

        // Generate optimization events
        if (self.system_pulse.resonance < 0.5) {
            timing.queueEvent(.{
                .type = .SystemOverload,
                .priority = .High,
                .timestamp = timing.getCurrentTime(),
                .data = .{ .system = .{
                    .load = @floatToInt(u8, self.system_pulse.global_wave.amplitude),
                    .temperature = @floatToInt(u8, self.system_pulse.resonance * 100),
                }},
            });
        }
    }

    fn handlePowerLimit(self: *ExecutionCore) void {
        // Reduce system activity
        self.active_cores = std.math.max(2, self.active_cores - 1);

        // Lower task amplitudes gradually
        for (self.scheduler.tasks.items) |*task| {
            if (task.flow.amplitude > 50) {
                task.flow.amplitude -= 5;
            }
        }

        // Update global wave
        self.system_pulse.global_wave.amplitude =
            std.math.max(30, self.system_pulse.global_wave.amplitude -% 10);
    }

    fn handleEvents(self: *ExecutionCore) void {
        while (timing.getPriorityEvent()) |event| {
            switch (event.type) {
                .SystemOverload => self.handleOverload(event),
                .MemoryLow => self.handleMemoryPressure(event),
                .HardwareError => self.handleHardwareError(event),
                else => {}, // Handle other events
            }
        }
    }

    fn harmonizeSystem(self: *ExecutionCore) void {
        // Adjust system parameters based on current state
        const resonance = self.system_pulse.resonance;

        if (resonance < 0.3) {
            // System is in discord - take corrective action
            self.active_cores = 2; // Reduce to minimal cores
            self.scheduler.tasks.items[0].flow.amplitude = 20;
        } else if (resonance > 0.8) {
            // System is in harmony - optimize for performance
            self.active_cores = 6;
            self.scheduler.tasks.items[0].flow.amplitude = 90;
        }

        // Balance core waves
        var total_amplitude: u32 = 0;
        for (self.system_pulse.core_waves) |wave| {
            total_amplitude += wave.amplitude;
        }

        const target_amplitude = total_amplitude / @as(u32, self.active_cores);
        for (self.system_pulse.core_waves) |*wave| {
            if (wave.amplitude > target_amplitude) {
                wave.amplitude -%= 1;
            } else if (wave.amplitude < target_amplitude) {
                wave.amplitude +%= 1;
            }
        }
    }

    fn balanceCoreLoad(self: *ExecutionCore) void {
        var core_loads: [6]u8 = .{0} ** 6;

        // Calculate load per core
        for (self.scheduler.tasks.items) |task| {
            if (task.flow.core_affinity) |core| {
                core_loads[core] += task.flow.amplitude;
            }
        }

        // Redistribute tasks if needed
        for (self.scheduler.tasks.items) |*task| {
            if (task.flow.core_affinity) |current_core| {
                if (core_loads[current_core] > 80) {
                    // Find less loaded core
                    var min_load: u8 = 255;
                    var target_core: u8 = current_core;

                    for (core_loads) |load, core| {
                        if (load < min_load) {
                            min_load = load;
                            target_core = @intCast(u8, core);
                        }
                    }

                    if (target_core != current_core) {
                        // Move task to less loaded core
                        task.flow.core_affinity = target_core;
                        core_loads[current_core] -= task.flow.amplitude;
                        core_loads[target_core] += task.flow.amplitude;
                    }
                }
            }
        }
    }

    fn handleOverload(self: *ExecutionCore, event: event_system.Event) void {
        _ = event;
        // Reduce system load
        self.active_cores = std.math.max(2, self.active_cores - 1);

        // Lower task amplitudes
        for (self.scheduler.tasks.items) |*task| {
            if (task.flow.amplitude > 50) {
                task.flow.amplitude -= 10;
            }
        }
    }

    fn handleMemoryPressure(self: *ExecutionCore, event: event_system.Event) void {
        _ = event;
        // Trigger memory optimization
        for (self.scheduler.tasks.items) |*task| {
            if (task.state != .Critical) {
                task.state = .Resonating;
            }
        }
    }

    fn handleHardwareError(self: *ExecutionCore, event: event_system.Event) void {
        _ = event;
        // Reset affected core wave
        if (event.data.hardware.device_id < 6) {
            const core = event.data.hardware.device_id;
            self.system_pulse.core_waves[core].amplitude = 50;
            self.system_pulse.core_waves[core].phase = 0;
        }
    }

    pub fn handleTaskPulse(self: *ExecutionCore, task_id: usize, amplitude: usize) syscall_table.SyscallResult {
        if (self.findTaskById(task_id)) |task| {
            const new_amplitude = @intCast(u8, std.math.min(amplitude, 100));
            task.flow.amplitude = new_amplitude;

            // Adjust system pulse based on task changes
            self.system_pulse.adjustWave(task_id, new_amplitude);

            return syscall_table.SyscallResult{ .success = new_amplitude };
        }
        return syscall_table.SyscallResult{ .error = syscall_table.SyscallError.ResourceNotFound };
    }

    pub fn handleTaskHarmonize(self: *ExecutionCore, task_id: usize, harmony_flags: usize) syscall_table.SyscallResult {
        if (self.findTaskById(task_id)) |task| {
            const resonance = @intToFloat(f32, harmony_flags & 0xFF) / 255.0;
            task.flow.resonance = resonance;

            // Update task state based on harmony flags
            if ((harmony_flags & 0x100) != 0) {
                task.state = .Resonating;
            }

            self.harmonizeSystem(); // Rebalance system harmony
            return syscall_table.SyscallResult{ .success = @floatToInt(usize, resonance * 100) };
        }
        return syscall_table.SyscallResult{ .error = syscall_table.SyscallError.ResourceNotFound };
    }

    pub fn handleResourceResonate(self: *ExecutionCore, resource_id: usize, resonance_level: usize) syscall_table.SyscallResult {
        const max_resources = 16; // Maximum number of tracked resources
        if (resource_id >= max_resources) {
            return syscall_table.SyscallResult{ .error = syscall_table.SyscallError.InvalidArgument };
        }

        // Normalize resonance level to 0-1 range
        const normalized_resonance = @intToFloat(f32, resonance_level & 0xFF) / 255.0;

        // Apply resource resonance through system pulse
        self.system_pulse.setResourceResonance(resource_id, normalized_resonance);

        // Trigger optimization if resonance is significantly changed
        if (normalized_resonance < 0.3 or normalized_resonance > 0.8) {
            self.optimizeExecution();
        }

        return syscall_table.SyscallResult{ .success = resonance_level };
    }

    fn findTaskById(self: *ExecutionCore, task_id: usize) ?*scheduler.Task {
        for (self.scheduler.tasks.items) |*task| {
            if (task.id == task_id) {
                return task;
            }
        }
        return null;
    }
};
