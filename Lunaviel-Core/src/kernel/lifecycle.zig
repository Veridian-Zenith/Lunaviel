pub fn manageLifecycle(task_id: usize) void {
    if (task_list[task_id].state == .Sleeping and system_load < 20) {
        task_list[task_id].state = .Active;
    } else if (system_load > 85) {
        task_list[task_id].state = .Dormant;
    }
}

pub fn stabilizeExecution() void {
    for (task_list) |task| {
        if (task.state == .Active and system_load > 90) {
            task.state = .Sleeping;
        }
    }
}
