pub fn wait(task_id: usize) void {
    while (task_list[task_id].state != .Dormant) {}
}

pub fn signal(task_id: usize) void {
    task_list[task_id].state = .Active;
}
