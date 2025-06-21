const std = @import("std");

pub fn build(b: *std.Build) void {
    const exe = b.addExecutable(.{
        .name = "bf_compiler",
        .root_source_file = b.path("bf_compiler.zig"),
        .target = b.graph.host,
        .optimize = std.builtin.OptimizeMode.Debug,
    });

    b.installArtifact(exe);
}