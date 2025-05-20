pub fn stabilizeFlow() void {
    for (task_list) |task| {
        if (task.state == .Active and system_load > 90) {
            task.state = .Sleeping;
        }
    }
}
