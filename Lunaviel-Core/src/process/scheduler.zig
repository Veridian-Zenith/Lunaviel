const std = @import("std");
const pulse = @import("../kernel/pulse.zig");
const timing = @import("../kernel/timing.zig");

pub const TaskState = enum {
    Awakening,   // Task is being initialized
    Flowing,     // Task is actively running
    Resonating,  // Task is waiting for resources
    Dormant,     // Task is sleeping
    Dissolving,  // Task is being terminated
};

pub const TaskFlow = struct {
    amplitude: u8,     // Current task energy (0-100)
    phase: f32,       // Position in system pulse cycle
    resonance: f32,   // Harmony with system rhythm
    core_affinity: ?u8, // Preferred CPU core
};

pub const Task = struct {
    id: u32,
    state: TaskState,
    flow: TaskFlow,
    stack_ptr: usize,
    entry_point: usize,
    priority: u8,
    quantum: u32,
    last_cpu: u8,

    pub fn init(id: u32, entry: usize, stack: usize, prio: u8) Task {
        return .{
            .id = id,
            .state = .Awakening,
            .flow = .{
                .amplitude = 50,
                .phase = 0.0,
                .resonance = 1.0,
                .core_affinity = null,
            },
            .stack_ptr = stack,
            .entry_point = entry,
            .priority = prio,
            .quantum = 100,
            .last_cpu = 0,
        };
    }
};

pub const Scheduler = struct {
    tasks: std.ArrayList(Task),
    current_task: ?*Task,
    system_pulse: pulse.SystemPulse,
    last_schedule_time: u64,

    pub fn init(allocator: std.mem.Allocator) Scheduler {
        return .{
            .tasks = std.ArrayList(Task).init(allocator),
            .current_task = null,
            .system_pulse = pulse.SystemPulse.init(),
            .last_schedule_time = 0,
        };
    }

    pub fn schedule(self: *Scheduler) void {
        const current_time = timing.getCurrentTime();

        // Evolve system pulse
        self.system_pulse.evolve();

        // Update task flows
        for (self.tasks.items) |*task| {
            self.updateTaskFlow(task);
        }

        // Select next task based on resonance
        if (self.selectNextTask()) |next| {
            if (self.current_task) |current| {
                if (current.id != next.id) {
                    self.switchTasks(current, next);
                }
            } else {
                self.activateTask(next);
            }
        }

        self.last_schedule_time = current_time;
    }

    fn updateTaskFlow(self: *Scheduler, task: *Task) void {
        // Align task phase with system pulse
        const phase_diff = @fabs(task.flow.phase - self.system_pulse.global_wave.phase);

        // Adjust task amplitude based on system state
        if (phase_diff < 0.1) {
            // Task is in harmony - increase energy
            if (task.flow.amplitude < 100) {
                task.flow.amplitude += 5;
            }
            task.flow.resonance = std.math.min(1.0, task.flow.resonance + 0.1);
        } else if (phase_diff > std.math.pi) {
            // Task is out of phase - decrease energy
            if (task.flow.amplitude > 0) {
                task.flow.amplitude -= 3;
            }
            task.flow.resonance = std.math.max(0.0, task.flow.resonance - 0.05);
        }

        // Update task state based on flow
        if (task.flow.amplitude < 10) {
            task.state = .Dormant;
        } else if (task.flow.resonance < 0.3) {
            task.state = .Resonating;
        } else if (task.state != .Flowing) {
            task.state = .Awakening;
        }
    }

    fn selectNextTask(self: *Scheduler) ?*Task {
        var best_task: ?*Task = null;
        var best_score: f32 = -1.0;

        for (self.tasks.items) |*task| {
            if (task.state == .Awakening or task.state == .Flowing) {
                const score = self.calculateTaskScore(task);
                if (score > best_score) {
                    best_score = score;
                    best_task = task;
                }
            }
        }

        return best_task;
    }

    fn calculateTaskScore(self: *Scheduler, task: *Task) f32 {
        var score = @intToFloat(f32, task.flow.amplitude) / 100.0;
        score *= task.flow.resonance;
        score *= @intToFloat(f32, 255 - task.priority) / 255.0;

        if (task.flow.core_affinity) |core| {
            const core_wave = &self.system_pulse.core_waves[core];
            if (core_wave.state == .Peak) {
                score *= 1.2;
            }
        }

        return score;
    }

    fn switchTasks(self: *Scheduler, from: *Task, to: *Task) void {
        saveContext(from);
        self.current_task = to;
        loadContext(to);
    }

    fn activateTask(self: *Scheduler, task: *Task) void {
        self.current_task = task;
        task.state = .Flowing;
        loadContext(task);
    }
};

fn saveContext(task: *Task) void {
    // Save CPU context to task
    asm volatile (
        \\mov %%rsp, %[stack]
        : [stack] "=m" (task.stack_ptr)
    );
}

fn loadContext(task: *Task) void {
    // Restore CPU context from task
    asm volatile (
        \\mov %[stack], %%rsp
        \\jmp *%[entry]
        :
        : [stack] "m" (task.stack_ptr),
          [entry] "m" (task.entry_point)
    );
}
