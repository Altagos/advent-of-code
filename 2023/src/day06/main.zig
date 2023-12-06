const std = @import("std");
const util = @import("util");

pub const std_options = util.std_options;

const data = @embedFile("data.txt");

const ParseResult = struct { []u64, []u64 };

fn parse_input(allocator: std.mem.Allocator, input: []const u8, ignore_spaces: bool) !ParseResult {
    var iter = std.mem.splitScalar(u8, input, '\n');
    const time_line = iter.next() orelse unreachable;
    const distance_line = iter.next() orelse unreachable;

    var times = std.ArrayList(u64).init(allocator);
    defer times.deinit();

    var distances = std.ArrayList(u64).init(allocator);
    defer distances.deinit();

    if (ignore_spaces) {
        const time = try std.mem.replaceOwned(u8, allocator, time_line[5..], " ", "");
        try times.append(try std.fmt.parseUnsigned(u64, time, 0));

        const distance = try std.mem.replaceOwned(u8, allocator, distance_line[9..], " ", "");
        try distances.append(try std.fmt.parseUnsigned(u64, distance, 0));
    } else {
        var times_iter = std.mem.tokenizeAny(u8, time_line[5..], " ");
        while (times_iter.next()) |time| {
            try times.append(try std.fmt.parseUnsigned(u64, time, 0));
        }

        var distances_iter = std.mem.tokenizeAny(u8, distance_line[9..], " ");
        while (distances_iter.next()) |distance| {
            try distances.append(try std.fmt.parseUnsigned(u64, distance, 0));
        }
    }

    return .{ try times.toOwnedSlice(), try distances.toOwnedSlice() };
}

fn count_different_ways(parsed: ParseResult) u64 {
    var result: u64 = 1;

    for (0..parsed[0].len) |i| {
        const time = parsed[0][i];
        const record = parsed[1][i];

        var max_time_hb = @divTrunc(time, 2);
        var time_hb: u64 = 1;

        while (time_hb * (time - time_hb) <= record and time_hb < time) : (time_hb += 1) {}

        max_time_hb *= 2;
        time_hb *= 2;
        if (time % 2 != 0) {
            max_time_hb += 2;
        } else {
            max_time_hb += 1;
        }

        result *= max_time_hb - time_hb;
    }

    return result;
}

pub fn part1(allocator: std.mem.Allocator, input: []const u8) !u64 {
    const parsed = try parse_input(allocator, input, false);
    return count_different_ways(parsed);
}

pub fn part2(allocator: std.mem.Allocator, input: []const u8) !u64 {
    const parsed = try parse_input(allocator, input, true);
    return count_different_ways(parsed);
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // std.log.info("processing part 1: {s}", .{data});
    const result_part1 = try part1(allocator, data);
    std.log.info("result part 1: {}", .{result_part1});

    const result_part2 = try part2(allocator, data);
    std.log.info("result part 2: {}", .{result_part2});
}

test "test example part 1" {
    const t = std.testing;

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const example_data =
        \\Time:      7  15   30
        \\Distance:  9  40  200
    ;

    const result = try part1(allocator, example_data);
    try t.expectEqual(@as(u64, 288), result);
}

test "test example part 2" {
    const t = std.testing;

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const example_data =
        \\Time:      7  15   30
        \\Distance:  9  40  200
    ;

    const result = try part2(allocator, example_data);
    try t.expectEqual(@as(u64, 71503), result);
}
