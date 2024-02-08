const std = @import("std");
const builtin = @import("builtin");
const fs = std.fs;
const process = std.process;

const Allocator = std.mem.Allocator;

const MINIMAL_ZIG_VERSION_STR = "0.12.0-dev.2644+42fcca49c";
const MINIMAL_ZIG_VERSION = std.SemanticVersion.parse(MINIMAL_ZIG_VERSION_STR) catch unreachable;

const Build = blk: {
    const current_version = builtin.zig_version;
    if (current_version.order(MINIMAL_ZIG_VERSION) == .lt) {
        @compileError("zig version is too old");
    }
    if (builtin.os.tag != .linux) {
        @compileError("It uses `grub-mkrescue` to make iso, and it works well only at Linux.");
    }

    break :blk std.Build;
};

pub fn build(b: *Build) anyerror!void {
    const target = b.standardTargetOptions(.{
        .default_target = try std.zig.CrossTarget.parse(
            .{
                .arch_os_abi = "x86_64-freestanding",
                .cpu_features = "baseline-mmx-sse-sse2-x87+soft_float",
            },
        ),
    });
    const optimize = b.standardOptimizeOption(.{});

    const kernel = b.addExecutable(.{
        .name = "kernel.bin",
        .root_source_file = .{ .path = "src/kernel/kmain.zig" },
        .target = target,
        .optimize = optimize,
    });

    const asm_files = [_][]const u8{
        "src/bootloader/multiboot_header.s",
        "src/bootloader/boot.s",
        "src/bootloader/long_mode.s",
    };
    inline for (asm_files) |@"asm"| {
        kernel.addAssemblyFile(.{ .path = @"asm" });
    }
    kernel.setLinkerScriptPath(.{ .path = "./linker.ld" });
    b.installArtifact(kernel);

    const run_cmd = b.addRunArtifact(kernel);
    run_cmd.step.dependOn(b.getInstallStep());

    // clear directories step
    const directories = [_][]const u8{
        "./isodir",
        "./zig-cache/",
        "./zig-out/",
        "./AxiomOS.iso",
    };

    const clean_step = b.step("clean", "clear built directories");

    for (directories) |dir| {
        const step = b.addSystemCommand(&[_][]const u8{ "/bin/rm", "-rf", dir });
        clean_step.dependOn(&step.step);
    }

    // compile-kernel step
    const make_iso_step = b.step("make-iso", "install the grub on my kernel");
    const make_iso_substep = b.addSystemCommand(&[_][]const u8{
        "grub-mkrescue",
        "-o",
        "AxiomOS.iso",
        "isodir",
    });

    const build_iso_step = try b.allocator.create(std.Build.Step);
    defer b.allocator.destroy(build_iso_step);
    build_iso_step.* = std.Build.Step.init(.{
        .id = .custom,
        .name = "build-iso",
        .owner = b,
        .makeFn = buildIso,
    });
    make_iso_step.dependOn(build_iso_step);
    make_iso_step.dependOn(&make_iso_substep.step);

    // run qemu step
    const run_qemu_step = b.step("run-qemu", "run qemu");
    const run_qemu_substep = b.addSystemCommand(&[_][]const u8{
        "qemu-system-x86_64",
        "-cdrom",
        "AxiomOS.iso",
    });
    run_qemu_step.dependOn(&run_qemu_substep.step);
}

fn buildIso(step: *Build.Step, node: *std.Progress.Node) anyerror!void {
    _ = step;
    _ = node;

    const grub_cfg =
        \\menuentry "AxiomOS" {
        \\    multiboot2 /boot/kernel.bin
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
    fs.cwd().copyFile("./zig-out/bin/kernel.bin", fs.cwd(), "./isodir/boot/kernel.bin", .{}) catch |err| {
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
