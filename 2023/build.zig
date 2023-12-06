const std = @import("std");

const required_zig_version = std.SemanticVersion.parse("0.12.0-dev.1769+bf5ab5451") catch unreachable;

pub fn build(b: *std.Build) void {
    if (comptime @import("builtin").zig_version.order(required_zig_version) == .lt) {
        std.debug.print("Warning: Your version of Zig too old. You will need to download a newer build\n", .{});
        std.os.exit(1);
    }

    const target = b.standardTargetOptions(.{});
    const mode = b.standardOptimizeOption(.{});
    const options = b.addOptions();

    const util = b.addSharedLibrary(.{
        .name = "util",
        .root_source_file = .{ .path = "src/util.zig" },
        .target = target,
        .optimize = mode,
    });
    const util_module = b.createModule(.{
        .source_file = .{ .path = "src/util.zig" },
        .dependencies = &[_]std.build.ModuleDependency{},
    });
    b.installArtifact(util);

    const spall = b.dependency("spall", .{});
    const spall_module = spall.module("spall");

    const install_all = b.step("install_all", "Install all days");
    const run_all = b.step("run_all", "Run all days");

    // Set up an exe for each day
    var day: u32 = 1;
    while (day <= 25) : (day += 1) {
        const dayString = b.fmt("day{:0>2}", .{day});
        const zigFile = b.fmt("src/{s}/main.zig", .{dayString});

        const exe = b.addExecutable(.{
            .name = dayString,
            .root_source_file = .{ .path = zigFile },
            .target = target,
            .optimize = mode,
        });
        exe.addModule("util", util_module);
        exe.addModule("spall", spall_module);

        exe.addOptions("build_options", options);

        const install_cmd = b.addInstallArtifact(exe, .{});

        const build_test = b.addTest(.{
            .root_source_file = .{ .path = zigFile },
            .target = target,
            .optimize = mode,
        });
        build_test.addModule("util", util_module);
        build_test.addModule("spall", spall_module);

        build_test.addOptions("build_options", options);

        const run_test = b.addRunArtifact(build_test);

        {
            const step_key = b.fmt("install_{s}", .{dayString});
            const step_desc = b.fmt("Install {s}.exe", .{dayString});
            const install_step = b.step(step_key, step_desc);
            install_step.dependOn(&install_cmd.step);
            install_all.dependOn(&install_cmd.step);
        }

        {
            const step_key = b.fmt("test_{s}", .{dayString});
            const step_desc = b.fmt("Run tests in {s}", .{zigFile});
            const step = b.step(step_key, step_desc);
            step.dependOn(&run_test.step);
        }

        const run_cmd = b.addRunArtifact(exe);
        if (b.args) |args| {
            run_cmd.addArgs(args);
        }

        const run_desc = b.fmt("Run {s}", .{dayString});
        const run_step = b.step(dayString, run_desc);
        run_step.dependOn(&run_cmd.step);
        run_all.dependOn(&run_cmd.step);
    }
}
