const std = @import("std");
const util = @import("util");

pub const std_options = util.std_options;

const data = @embedFile("data.txt");

pub fn left_or_right(char: u8) usize {
    return switch (char) {
        'L' => 0,
        'R' => 1,
        else => unreachable,
    };
}

const Direction = @TypeOf(.enum_literal);
const LeftRight = struct { []u8, []u8 };

pub fn part1(allocator: std.mem.Allocator, input: []const u8) u64 {
    var lines = util.lineIteratorTokens(input);

    var idx: u64 = 0;
    var instructions: []const u8 = undefined;

    var directions = std.StringHashMap(LeftRight).init(allocator);
    defer directions.deinit();

    const start: []u8 = @constCast("AAA");
    const end: []u8 = @constCast("ZZZ");

    while (lines.next()) |line| : (idx += 1) {
        if (idx == 0) {
            instructions = line;
            continue;
        }

        var line_content = util.tokenizeSequence(u8, line, " = ");
        const direction = @constCast(line_content.next() orelse return 0);
        const left_right = @constCast(line_content.next() orelse return 0);
        std.mem.replaceScalar(u8, left_right, '(', ' ');
        std.mem.replaceScalar(u8, left_right, ')', ' ');
        std.mem.replaceScalar(u8, left_right, ',', ' ');

        var left_right_iter = util.tokenizeScalar(u8, left_right, ' ');
        const left = @constCast(left_right_iter.next() orelse "");
        const right = @constCast(left_right_iter.next() orelse "");

        directions.put(direction, .{ left, right }) catch return 0;
    }

    var current = start;
    var reached_the_end = false;
    var round: u64 = 0;
    var curr_idx: u64 = 0;

    while (!reached_the_end) {
        if (std.mem.eql(u8, end, current)) {
            reached_the_end = true;
            break;
        }

        const next = directions.get(current) orelse return 0;
        const lor = if (left_or_right(instructions[curr_idx]) == 0) next[0] else next[1];
        current = lor;

        if (curr_idx == instructions.len - 1) {
            curr_idx = 0;
            round += 1;
        } else {
            curr_idx += 1;
        }
    }

    return round * instructions.len + curr_idx;
}

pub fn part2(allocator: std.mem.Allocator, input: []const u8) !u64 {
    var lines = util.lineIteratorTokens(input);

    var idx: u64 = 0;
    var instructions: []const u8 = undefined;

    var directions = std.StringHashMap(LeftRight).init(allocator);
    defer directions.deinit();

    var start = std.ArrayList([]u8).init(allocator);
    defer start.deinit();
    // const end: []u8 = @constCast("ZZZ");

    while (lines.next()) |line| : (idx += 1) {
        if (idx == 0) {
            instructions = line;
            continue;
        }

        var line_content = util.tokenizeSequence(u8, line, " = ");
        const direction = @constCast(line_content.next() orelse return 0);
        const left_right = @constCast(line_content.next() orelse return 0);
        std.mem.replaceScalar(u8, left_right, '(', ' ');
        std.mem.replaceScalar(u8, left_right, ')', ' ');
        std.mem.replaceScalar(u8, left_right, ',', ' ');

        var left_right_iter = util.tokenizeScalar(u8, left_right, ' ');
        const left = @constCast(left_right_iter.next() orelse "");
        const right = @constCast(left_right_iter.next() orelse "");

        directions.put(direction, .{ left, right }) catch return 0;

        if (std.mem.endsWith(u8, direction, "A")) {
            std.debug.print("at: {}, {s}\n", .{ idx, direction });
            start.append(direction) catch return 0;
        }
    }

    var current = start.toOwnedSlice() catch return 0;

    var reached_the_end = false;
    var round: u64 = 0;
    var curr_idx: u64 = 0;

    while (!reached_the_end) {
        var all_end_with_z = false;
        const go_lor = left_or_right(instructions[curr_idx]);

        for (0..current.len) |didx| {
            const next = directions.get(current[didx]) orelse return 0;
            const lor = if (go_lor == 0) next[0] else next[1];

            // std.debug.print("{s} -> {s} {s}, {} => {s}\n", .{
            //     current[didx],
            //     next[0],
            //     next[1],
            //     go_lor,
            //     lor,
            // });

            current[didx] = lor;
            if (std.mem.endsWith(u8, lor, "Z")) {
                // all_end_with_z = if (all_end_with_z) true else false;
                all_end_with_z = if (didx == 0) true else all_end_with_z == true;
            } else {
                all_end_with_z = false;
            }
        }

        if (curr_idx == instructions.len - 1) {
            curr_idx = 0;
            round += 1;
        } else {
            curr_idx += 1;
        }

        // std.debug.print("steps: {}\n\n", .{round * instructions.len + curr_idx});

        if (all_end_with_z) {
            reached_the_end = true;
            break;
        }

        if (round * instructions.len + curr_idx > 1_000_000_000) break;
    }

    return round * instructions.len + curr_idx;
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // std.log.info("processing part 1: {s}", .{data});
    const result_part1 = part1(allocator, data);
    std.log.info("result part 1: {}", .{result_part1});

    const result_part2 = try part2(allocator, data);
    std.log.info("result part 2: {}", .{result_part2});
}

const example_data_1 =
    \\LLR
    \\
    \\AAA = (BBB, BBB)
    \\BBB = (AAA, ZZZ)
    \\ZZZ = (ZZZ, ZZZ)
;

const example_data_2 =
    \\LR
    \\
    \\11A = (11B, XXX)
    \\11B = (XXX, 11Z)
    \\11Z = (11B, XXX)
    \\22A = (22B, XXX)
    \\22B = (22C, 22C)
    \\22C = (22Z, 22Z)
    \\22Z = (22B, 22B)
    \\XXX = (XXX, XXX)
;

// test "test example part 1" {
//     var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
//     defer arena.deinit();
//     const allocator = arena.allocator();

//     const result = part1(allocator, example_data_1);
//     std.debug.print("\n\nResult: {}", .{result});
// }

test "test example part 2" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const result = try part2(allocator, example_data_2);
    std.debug.print("\n\nResult: {}", .{result});
}
