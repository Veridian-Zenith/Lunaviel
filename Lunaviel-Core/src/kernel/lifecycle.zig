pub fn manageLifecycle(task_id: usize) void {
    if (task_list[task_id].state == .Sleeping and system_load < 20) {
        task_list[task_id].state = .Active;
    } else if (system_load > 85) {
        task_list[task_id].state = .Dormant;
    }
}
