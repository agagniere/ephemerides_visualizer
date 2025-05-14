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
});

/// Initialize axe logging instance and setup raylib to log with it
pub fn init(gpa: Allocator) !void {
    var env = try std.process.getEnvMap(gpa);
    defer env.deinit();

    try axe_log.init(gpa, null, &env);
    log_buffer = .init(gpa);
    c.SetTraceLogCallback(raylib_log_callback);
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
    var args_copy = @cVaCopy(args);
    defer @cVaEnd(&args_copy);
    const size = c.vsnprintf(null, 0, format, &args_copy);
    log_buffer.ensureTotalCapacity(@intCast(size + 1)) catch unreachable;
    log_buffer.items.len = @intCast(c.vsnprintf(log_buffer.items.ptr, log_buffer.capacity, format, args));

    switch (level) {
        .trace, .debug => raylog.debug("{s}", .{log_buffer.items}),
        .info => raylog.info("{s}", .{log_buffer.items}),
        .warning => raylog.warn("{s}", .{log_buffer.items}),
        .err => raylog.err("{s}", .{log_buffer.items}),
        .fatal => raylog.err("[FATAL] {s}", .{log_buffer.items}),
        else => unreachable,
    }
    log_buffer.clearRetainingCapacity();
}
