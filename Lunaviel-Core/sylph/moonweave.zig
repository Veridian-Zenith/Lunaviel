const std = @import("std");
const Task = @import("taskweave.zig").Task;
const StarThread = @import("starthread.zig").StarThread;
const log = @import("../seer/oracle.zig").log;

// Hardware-specific constants based on the target system (12th Gen Intel i3-1215U)
const MAX_CORES = 6;  // Physical cores
const MAX_THREADS = 8; // Logical threads
const MAX_TASKS = 256;
const TIME_SLICE = 10; // milliseconds
const CACHE_LINE_SIZE = 64; // bytes, common in modern Intel CPUs

pub const CoreState = enum {
    Idle,
    Active,
    Halted,
};

pub const CoreInfo = struct {
    id: u32,
    state: CoreState,
    current_task: ?*Task,
    load: u32, // Current load percentage (0-100)
};

pub const MoonScheduler = struct {
    tasks: [MAX_TASKS]?*Task,
    cores: [MAX_CORES]CoreInfo,
    threads_per_core: [MAX_CORES]u32,
    current_task: usize,
    task_count: usize,
    quantum_remaining: u32,
    active_cores: u32,

    // Cache-related metrics
    cache_misses: u64,
    cache_hits: u64,

    pub fn init() MoonScheduler {
        var scheduler = MoonScheduler{
            .tasks = [_]?*Task{null} ** MAX_TASKS,
            .cores = undefined,
            .threads_per_core = [_]u32{2} ** MAX_CORES, // Initialize with 2 threads per core
            .current_task = 0,
            .task_count = 0,
            .quantum_remaining = TIME_SLICE,
            .active_cores = 0,
            .cache_misses = 0,
            .cache_hits = 0,
        };

        // Initialize core information
        for (scheduler.cores) |*core, i| {
            core.* = CoreInfo{
                .id = @intCast(u32, i),
                .state = .Idle,
                .current_task = null,
                .load = 0,
            };
        }

        return scheduler;
    }

    pub fn add_task(self: *MoonScheduler, task: *Task) bool {
        if (self.task_count >= MAX_TASKS) {
            log("Cannot add more tasks - maximum reached");
            return false;
        }

        var idx: usize = 0;
        while (idx < MAX_TASKS) : (idx += 1) {
            if (self.tasks[idx] == null) {
                self.tasks[idx] = task;
                self.task_count += 1;
                log("Added task to scheduler");
                return true;
            }
        }
        return false;
    }

    pub fn remove_task(self: *MoonScheduler, task_id: u32) bool {
        var idx: usize = 0;
        while (idx < MAX_TASKS) : (idx += 1) {
            if (self.tasks[idx]) |task| {
                if (task.id == task_id) {
                    self.tasks[idx] = null;
                    self.task_count -= 1;
                    log("Removed task from scheduler");
                    return true;
                }
            }
        }
        return false;
    }

    pub fn get_next_task(self: *MoonScheduler) ?*Task {
        if (self.task_count == 0) return null;

        // Enhanced round-robin with priority and core affinity consideration
        var highest_priority: i32 = -1;
        var best_task: ?*Task = null;
        var best_core: u32 = 0;

        // Find the most suitable task based on priority and core availability
        var idx: usize = 0;
        while (idx < MAX_TASKS) : (idx += 1) {
            if (self.tasks[idx]) |task| {
                if (task.state != .Ready) continue;

                const task_priority = @intCast(i32, task.priority);
                if (task_priority > highest_priority) {
                    // Check core affinity and load
                    const preferred_core = self.get_preferred_core(task);
                    if (preferred_core) |core_id| {
                        highest_priority = task_priority;
                        best_task = task;
                        best_core = core_id;
                    }
                }
            }
        }

        if (best_task) |task| {
            // Update core assignment
            self.cores[best_core].current_task = task;
            self.cores[best_core].state = .Active;
            return task;
        }

        return null;
    }

    fn get_preferred_core(self: *MoonScheduler, task: *Task) ?u32 {
        var lowest_load: u32 = 100;
        var best_core: ?u32 = null;

        // Find core with lowest load
        for (self.cores) |core| {
            if (core.load < lowest_load) {
                lowest_load = core.load;
                best_core = core.id;
            }
        }

        return best_core;
    }

    pub fn update_core_metrics(self: *MoonScheduler) void {
        var active_cores: u32 = 0;

        for (self.cores) |*core| {
            // Update core load based on task execution time
            if (core.current_task != null) {
                core.state = .Active;
                active_cores += 1;
            } else if (core.state == .Active) {
                core.state = .Idle;
            }
        }

        self.active_cores = active_cores;
    }

    pub fn get_scheduler_stats(self: *MoonScheduler) struct {
        active_cores: u32,
        total_tasks: usize,
        cache_efficiency: f32,
    } {
        const cache_total = self.cache_hits + self.cache_misses;
        const cache_efficiency = if (cache_total > 0)
            @intToFloat(f32, self.cache_hits) / @intToFloat(f32, cache_total)
        else
            0.0;

        return .{
            .active_cores = self.active_cores,
            .total_tasks = self.task_count,
            .cache_efficiency = cache_efficiency,
        };
    }

    pub fn tick(self: *MoonScheduler) void {
        if (self.quantum_remaining > 0) {
            self.quantum_remaining -= 1;
            return;
        }

        // Time slice expired, force a context switch
        if (self.get_next_task()) |next_task| {
            if (self.tasks[self.current_task]) |current_task| {
                if (current_task.state == .Running) {
                    current_task.state = .Ready;
                }
            }
            next_task.state = .Running;
            self.quantum_remaining = TIME_SLICE;
            // Trigger context switch
            StarThread.switch_context(next_task);
        }
    }

    // Enhanced yield with core awareness
    pub fn yield(self: *MoonScheduler) void {
        if (self.current_task < MAX_TASKS and self.tasks[self.current_task] != null) {
            // Update current core metrics before yielding
            const current_core = self.get_current_core();
            if (current_core) |core| {
                core.state = .Idle;
                core.current_task = null;
            }
        }

        self.quantum_remaining = 0;
        self.tick();
    }

    fn get_current_core(self: *MoonScheduler) ?*CoreInfo {
        // Find the core currently executing this task
        for (self.cores) |*core| {
            if (core.current_task != null and
                core.current_task.?.id == self.tasks[self.current_task].?.id) {
                return core;
            }
        }
        return null;
    }

    // Power management functions
    pub fn adjust_core_power(self: *MoonScheduler) void {
        // Implement power state management based on load
        for (self.cores) |*core| {
            switch (core.state) {
                .Idle => {
                    if (core.load < 10) {
                        core.state = .Halted;
                    }
                },
                .Halted => {
                    if (self.task_count > self.active_cores * 2) {
                        core.state = .Idle;
                    }
                },
                .Active => {}, // No changes needed
            }
        }
    }
};
