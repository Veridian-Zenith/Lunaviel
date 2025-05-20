pub fn invoke_syscall(syscall_id: u8, arg1: usize, arg2: usize) usize {
    var result: usize = undefined;
    asm volatile (
        "int 0x80"
        : "=a"(result)
        : "a"(syscall_id), "b"(arg1), "c"(arg2)
    );
    return result;
}
