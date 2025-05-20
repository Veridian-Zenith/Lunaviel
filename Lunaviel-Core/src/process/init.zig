pub fn initProcess() usize {
    const id = registerTask(@ptrToInt(&initProcess));
    activateTask(id);
    return id;
}
