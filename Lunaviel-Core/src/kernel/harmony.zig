pub fn balanceExecution() void {
    for (task_list) |task| {
        optimizeTask(task.id);
    }
}
