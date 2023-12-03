const std = @import("std");
const util = @import("util");

pub const std_options = util.std_options;

const data = @embedFile("data.txt");

pub fn part1(input: []const u8) usize {
    _ = input;
    return 0;
}

pub fn part2(input: []const u8) usize {
    _ = input;
    return;
}

pub fn main() !void {
    // std.log.info("processing part 1: {s}", .{data});
    const result_part1 = part1(data);
    std.log.info("result part 1: {}", .{result_part1});

    const result_part2 = part2(data);
    std.log.info("result part 2: {}", .{result_part2});
}

test "test example part 1" {}

test "test example part 2" {}
