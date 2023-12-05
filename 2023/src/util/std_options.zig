const std = @import("std");
const builtin = @import("builtin");

pub const log_level = if (builtin.mode == std.builtin.Mode.Debug) .debug else .info;

pub const logFn: fn (
    comptime message_level: std.log.Level,
    comptime scope: @TypeOf(.enum_literal),
    comptime format: []const u8,
    args: anytype,
) void = aocLogFn;

fn aocLogFn(
    comptime message_level: std.log.Level,
    comptime scope: @TypeOf(.enum_literal),
    comptime format: []const u8,
    args: anytype,
) void {
    const level_text = lt: {
        switch (message_level) {
            .err => {
                break :lt "\x1b[31merror\x1b[0m";
            },
            .warn => {
                break :lt "\x1b[33mwarning\x1b[0m";
            },
            .info => {
                break :lt "\x1b[32minfo\x1b[0m";
            },
            .debug => {
                break :lt "\x1b[34mdebug\x1b[0m";
            },
        }
    };
    const scope_prefix = "\x1b[90m[\x1b[0m" ++ @tagName(scope) ++ "\x1b[90m]\x1b[0m";

    const prefix = level_text ++ " " ++ scope_prefix ++ "\x1b[90m: \x1b[0m";

    std.debug.getStderrMutex().lock();
    defer std.debug.getStderrMutex().unlock();
    const stderr = std.io.getStdErr().writer();
    nosuspend stderr.print(prefix ++ format ++ "\x1b[0m\n", args) catch return;
}
