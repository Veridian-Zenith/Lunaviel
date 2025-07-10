const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .x86_64,
        .os_tag = .uefi,
    });

    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "lunaviel",
        .root_source_file = b.path("src/core/uefi_start.zig"),
        .target = target,
        .optimize = optimize,
    });

    // UEFI-specific configuration
    exe.entry = .disabled; // Disable default entry point

    // Required linker settings for UEFI
    exe.link_eh_frame_hdr = false;
    exe.link_emit_relocs = true;
    exe.single_threaded = true;
    exe.strip = true;

    // Add linker flag for entry point
    exe.addObjectFile(b.path("src/core/uefi_start.zig"));
    exe.step.addArgs(&.{
        "-femit-bin=lunaviel.efi",
        "--entry=efi_main",
    });

    // Add additional source files
    exe.root_module.addAnonymousImport("uefi_print", .{
        .source_file = b.path("src/core/uefi_print.zig"),
    });

    b.installArtifact(exe);
}
