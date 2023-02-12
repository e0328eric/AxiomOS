const std = @import("std");
const fs = std.fs;
const process = std.process;

const Allocator = std.mem.Allocator;

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{
        .default_target = std.zig.CrossTarget.parse(
            .{ .arch_os_abi = "x86-freestanding" },
        ) catch @panic("cannot parse target triple"),
    });
    const optimize = b.standardOptimizeOption(.{
        .preferred_optimize_mode = .ReleaseSmall,
    });

    const exe = b.addExecutable(.{
        .name = "fooOs.bin",
        .root_source_file = .{ .path = "kernel/boot.zig" },
        .target = target,
        .optimize = optimize,
    });
    exe.setLinkerScriptPath(.{ .path = "kernel/linker.ld" });
    exe.install();

    // clear directories step
    const directories = [_][]const u8{
        "./isodir",
        "./zig-cache/",
        "./zig-out/",
        "./fooOs.iso",
    };

    const clear_step = b.step("clear", "clear built directories");

    for (directories) |dir| {
        const step = b.addSystemCommand(&[_][]const u8{ "rm", "-rf", dir });
        clear_step.dependOn(&step.step);
    }

    // compile-kernel step
    const comp_kernel_step = b.step("compile-kernel", "install the grub on my kernel");
    const comp_kernel_substep = b.addSystemCommand(&[_][]const u8{
        "grub-mkrescue",
        "-o",
        "fooOs.iso",
        "isodir",
    });
    var build_iso_step = try b.allocator.create(std.Build.Step);
    defer b.allocator.destroy(build_iso_step);
    build_iso_step.* = std.Build.Step.init(.custom, "build-iso", b.allocator, buildIso);
    comp_kernel_step.dependOn(b.getInstallStep());
    comp_kernel_step.dependOn(build_iso_step);
    comp_kernel_step.dependOn(&comp_kernel_substep.step);

    // run qemu step
    const run_qemu_step = b.step("run-qemu", "run qemu");
    const run_qemu_substep = b.addSystemCommand(&[_][]const u8{
        "qemu-system-i386",
        "-cdrom",
        "fooOs.iso",
    });
    run_qemu_step.dependOn(&run_qemu_substep.step);
}

fn buildIso(step: *std.Build.Step) anyerror!void {
    _ = step;

    const grub_cfg =
        \\menuentry "fooOs" {
        \\    multiboot /boot/fooOs.bin
        \\}
    ;

    inline for (.{ "isodir", "isodir/boot", "isodir/boot/grub" }) |dir_name| {
        fs.cwd().makeDir(dir_name) catch |err| {
            switch (err) {
                error.PathAlreadyExists => {},
                else => return err,
            }
        };
    }
    fs.cwd().copyFile("./zig-out/bin/fooOs.bin", fs.cwd(), "./isodir/boot/fooOs.bin", .{}) catch |err| {
        switch (err) {
            error.FileNotFound => {
                std.log.err("use `zig build` to compile the kernel first\n", .{});
                return err;
            },
            else => return err,
        }
    };
    var file = try fs.cwd().createFile("./isodir/boot/grub/grub.cfg", .{});
    defer file.close();
    try file.writeAll(grub_cfg);
}
