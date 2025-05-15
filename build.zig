const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    //const rl_config: []const u8 = "-DSUPPORT_TRACELOG_DEBUG=1";
    const raylib = b.dependency("raylib", .{
        .target = target,
        .optimize = optimize,
        .raudio = false,
        .rshapes = false,
        .linux_display_backend = .X11,
        .shared = true,
        //.config = rl_config,
    });
    const rayzig = b.dependency("raylib_zig", .{ .target = target, .optimize = optimize });
    const units = b.dependency("unitz", .{ .target = target, .optimize = optimize });
    const axe = b.dependency("axe", .{ .target = target, .optimize = optimize });

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    exe_mod.addImport("raylib", rayzig.module("raylib"));
    exe_mod.addImport("raygui", rayzig.module("raygui"));
    exe_mod.addImport("units", units.module("unitz"));
    exe_mod.addImport("axe", axe.module("axe"));
    const exe = b.addExecutable(.{
        .name = "ephemerides_visualizer",
        .root_module = exe_mod,
    });
    exe.linkLibrary(raylib.artifact("raylib"));
    b.installArtifact(exe);

    { // Assets
        const orbvis = b.dependency("orbvis", .{});
        const install_textures = b.addInstallDirectory(.{
            .source_dir = orbvis.path("res/texture"),
            .install_dir = .{ .custom = "assets" },
            .install_subdir = "textures",
            .include_extensions = &.{".jpg"},
        });
        const options = b.addOptions();
        options.addOption([]const u8, "textures", b.getInstallPath(install_textures.options.install_dir, "textures"));
        options.addOptionPath("shaders", b.path("shaders"));
        options.addOptionPath("icon", b.path("images/icon-64.png"));
        exe_mod.addOptions("assets", options);
        exe.step.dependOn(&install_textures.step);
    }
    { // Run
        const run_step = b.step("run", "Run the app");
        const run_cmd = b.addRunArtifact(exe);
        run_cmd.step.dependOn(b.getInstallStep());
        if (b.args) |args| {
            run_cmd.addArgs(args);
        }
        run_step.dependOn(&run_cmd.step);
    }
}
