pub fn stabilizeExecution() void {
    for (task_list) |task| {
        manageLifecycle(task.id);
        optimizeTask(task.id);
        adjustPulse(task.id);
    }
}
