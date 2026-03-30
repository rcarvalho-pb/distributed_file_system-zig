const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    const queue_mod = b.addModule("genericQueue", .{
        .root_source_file = b.path("src/generic_queue/queue.zig"),
        .target = target,
    });

    const p2p_mod = b.addModule("p2p", .{
        .root_source_file = b.path("src/p2p/p2p.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "genericQueue", .module = queue_mod },
        },
    });

    const exe = b.addExecutable(.{
        .name = "distributed_file_system_zig",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),

            .target = target,
            .optimize = optimize,

            .imports = &.{
                .{ .name = "genericQueue", .module = queue_mod },
                .{ .name = "p2p", .module = p2p_mod },
            },
        }),
    });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const test_step = b.step("test", "Run tests");

    const tests = [_]*std.Build.Step.Compile{
        b.addTest(.{ .root_module = exe.root_module }),
        b.addTest(.{ .root_module = queue_mod }),
        b.addTest(.{ .root_module = p2p_mod }),
    };

    for (tests) |t| {
        const run_test = b.addRunArtifact(t);
        test_step.dependOn(&run_test.step);
    }
}
