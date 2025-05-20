pub fn optimizeTask(task_id: usize) void {
    if (task_list[task_id].state == .Dormant) return;

    adjustPulse(task_id);

    if (system_load > 85) {
        task_list[task_id].state = .Sleeping;
    } else {
        task_list[task_id].state = .Active;
    }
}
