pub fn invoke_extended_syscall(call_id: u8, arg1: usize, arg2: usize, arg3: usize) usize {
    var result: usize = undefined;
    asm volatile (
        "int 0x81"
        : "=a"(result)
        : "a"(call_id), "b"(arg1), "c"(arg2), "d"(arg3)
    );
    return result;
}
