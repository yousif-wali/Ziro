const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create the ziro-collections module
    const collections_module = b.addModule("ziro-collections", .{
        .root_source_file = b.path("src/main.zig"),
    });

    // Unit tests
    const lib_unit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    // Queue-specific tests
    const queue_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/queue_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "ziro-collections", .module = collections_module },
            },
        }),
    });

    const run_queue_tests = b.addRunArtifact(queue_tests);

    // Test step
    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_lib_unit_tests.step);
    test_step.dependOn(&run_queue_tests.step);
}
