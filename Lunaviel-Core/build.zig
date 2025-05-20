const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .x86_64,
        .os_tag = .freestanding,
    });

    const exe = b.addExecutable(.{
        .name = "LunavielCore.bin", // outputs to zig-out/bin/
        .root_source_file = b.path("src/kernel/main.zig"),
        .target = target,
        .optimize = .Debug,
        .link_libc = false, // 👈 correctly placed
    });

    exe.setLinkerScript(b.path("src/boot/linker.ld"));

    b.installArtifact(exe);
    b.default_step.dependOn(&exe.step);
}
