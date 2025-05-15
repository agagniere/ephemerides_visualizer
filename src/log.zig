const std = @import("std");

const raylib = @import("raylib");
const axe = @import("axe");

const Allocator = std.mem.Allocator;

/// Global buffer to print raylib's logs inside
var log_buffer: std.ArrayList(u8) = undefined;

pub const axe_log = axe.Axe(.{
    .format = "[%l%s%L] %m\n",
    .scope_format = " %",
    .loc_format = " %f:%F:%l",
    .level_text = .{
        .debug = "DEBUG",
        .info = "INFO ",
        .warn = "WARN ",
        .err = "ERROR",
    },
    .styles = .{
        .debug = &.{.dim},
    },
});

/// Initialize axe logging instance and setup raylib to log with it
pub fn init(gpa: Allocator, raylib_log_level: raylib.TraceLogLevel) !void {
    var env = try std.process.getEnvMap(gpa);
    defer env.deinit();

    try axe_log.init(gpa, null, &env);
    log_buffer = try .initCapacity(gpa, 300);
    c.SetTraceLogCallback(raylib_log_callback);
    raylib.setTraceLogLevel(raylib_log_level);
}

pub fn deinit(gpa: Allocator) void {
    log_buffer.deinit();
    axe_log.deinit(gpa);
}

const c = struct {
    const RaylibLogCallback = *const fn (level: raylib.TraceLogLevel, format: [*:0]const u8, args: *std.builtin.VaList) callconv(.C) void;

    extern fn SetTraceLogCallback(callback: RaylibLogCallback) void;
    extern fn vsnprintf(str: [*c]u8, size: usize, format: [*:0]const u8, ap: *std.builtin.VaList) c_int;
};

const raylog = axe_log.scoped(.raylib);

fn raylib_log_callback(level: raylib.TraceLogLevel, format: [*:0]const u8, args: *std.builtin.VaList) callconv(.C) void {
    //var args_copy = @cVaCopy(args);
    //defer @cVaEnd(&args_copy);

    const needed = c.vsnprintf(log_buffer.items.ptr, log_buffer.capacity, format, args);
    const status = std.posix.errno(needed);

    if (status != .SUCCESS) {
        axe_log.errAt(@src(), "vsnprintf failed: {s}", .{@tagName(status)});
        return;
    }

    const length: usize = @intCast(needed);
    if (length >= log_buffer.capacity) {
        unreachable;
        // log_buffer.ensureTotalCapacity(length) catch |err| {
        //     axe_log.errAt(@src(), "Failed to grow buffer: {s}", .{@errorName(err)});
        //     return;
        // };
        // _ = c.vsnprintf(log_buffer.items.ptr, log_buffer.capacity, format, &args_copy);
    }
    log_buffer.items.len = length;

    // Note: raylib debug logs are disabled at compile-time by default, in which case only trace logs remain at the "debug" level here.
    switch (level) {
        .trace, .debug => raylog.debug("{s}", .{log_buffer.items}),
        .info => raylog.info("{s}", .{log_buffer.items}),
        .warning => raylog.warn("{s}", .{log_buffer.items}),
        .err => raylog.err("{s}", .{log_buffer.items}),
        .fatal => raylog.err("[FATAL] {s}", .{log_buffer.items}),
        .all, .none => unreachable,
    }
    log_buffer.clearRetainingCapacity();
}
