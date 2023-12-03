const std = @import("std");
const util = @import("util");

pub const std_options = util.std_options;

const data = @embedFile("data.txt");

const Digit = struct {
    const DigitLetters = enum {
        one,
        two,
        three,
        four,
        five,
        six,
        seven,
        eight,
        nine,
    };

    pub fn parse(input: []const u8) !u32 {
        return std.fmt.parseInt(u32, input, 10);
    }

    pub fn from_string(input: []const u8) !u32 {
        return Digit.parse(input) catch {
            return from_letter_string(input) catch error.NotADigit;
        };
    }

    pub fn from_letter_string(input: []const u8) !u32 {
        const letter_enum = std.meta.stringToEnum(DigitLetters, input) orelse return error.NotADigitWrittenInLetters;
        switch (letter_enum) {
            .one => return 1,
            .two => return 2,
            .three => return 3,
            .four => return 4,
            .five => return 5,
            .six => return 6,
            .seven => return 7,
            .eight => return 8,
            .nine => return 9,
        }
    }
};

fn parse_digits_in_line(line: []const u8) u32 {
    var count: u32 = 0;

    // first digit
    var idx: usize = 0;
    while (idx < line.len) : (idx += 1) {
        const digit = Digit.from_string(line[idx .. idx + 1]) catch continue;
        count += digit * 10;
        break;
    }

    // second digit
    idx = line.len - 1;
    while (idx >= 0) : (idx -= 1) {
        // std.debug.print("second digit\n", .{});
        const digit = Digit.from_string(line[idx .. idx + 1]) catch {
            if (idx == 0) {
                break;
            } else {
                continue;
            }
        };
        count += digit;
        break;
    }

    return count;
}

fn parse_line(allocator: std.mem.Allocator, input: []const u8) u32 {
    var count: u32 = 0;
    var digits_in_line = std.ArrayList(u32).init(allocator);
    defer digits_in_line.deinit();

    var idx: usize = 0;
    const range = [4]usize{ 1, 3, 4, 5 };
    while (idx < input.len + 1) : (idx += 1) {
        for (range) |i| inner: {
            if (idx + i <= input.len) {
                const digit = Digit.from_string(input[idx .. idx + i]) catch {
                    continue;
                };
                digits_in_line.append(digit) catch {
                    std.log.err("Could not append digit", .{});
                };
                break :inner;
            }
        }
    }

    // std.debug.print("in line {any}\n", .{digits_in_line.items});
    const first = digits_in_line.items[0];
    const last = digits_in_line.getLastOrNull() orelse first;
    count += first * 10 + last;

    return count;
}

pub fn part1(input: []const u8) u32 {
    var total: u32 = 0;
    var l: usize = 0;

    var iter = std.mem.splitSequence(u8, input, "\n");
    while (iter.next()) |line| : (l += 1) {
        const result = parse_digits_in_line(line);
        total += result;
        // std.debug.print("line {}: {} - total: {}\n", .{ l, result, total });
    }

    return total;
}

pub fn part2(input: []const u8) u32 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var total: u32 = 0;
    var l: usize = 0;

    var iter = std.mem.splitSequence(u8, input, "\n");
    while (iter.next()) |line| : (l += 1) {
        const result = parse_line(allocator, line);
        total += result;
        // std.debug.print("line {}: {} - total: {}\n", .{ l, result, total });
    }

    return total;
}

pub fn main() !void {
    // std.log.info("processing part 1: {s}", .{data});
    const result_part1 = part1(data);
    std.log.info("result part 1: {}", .{result_part1});

    const result_part2 = part2(data);
    std.log.info("result part 2: {}", .{result_part2});
}

test "test example lines part 1" {
    const t = std.testing;

    try t.expectEqual(@as(u32, 12), parse_digits_in_line("1abc2"));
    try t.expectEqual(@as(u32, 11), parse_digits_in_line("1abc"));
    try t.expectEqual(@as(u32, 11), parse_digits_in_line("11"));
    try t.expectEqual(@as(u32, 38), parse_digits_in_line("pqr3stu8vwx"));
    try t.expectEqual(@as(u32, 15), parse_digits_in_line("a1b2c3d4e5f"));
    try t.expectEqual(@as(u32, 77), parse_digits_in_line("treb7uchet"));
}

test "test example part 1" {
    const t = std.testing;

    const example_input =
        \\1abc2
        \\pqr3stu8vwx
        \\a1b2c3d4e5f
        \\treb7uchet
    ;

    try t.expectEqual(@as(u32, 142), part1(example_input));
}

test "test example lines part 2" {
    const t = std.testing;
    const allocator = t.allocator;

    try t.expectEqual(@as(u32, 29), parse_line(allocator, "two1nine"));
    try t.expectEqual(@as(u32, 83), parse_line(allocator, "eightwothree"));
    try t.expectEqual(@as(u32, 13), parse_line(allocator, "abcone2threexyz"));
    try t.expectEqual(@as(u32, 24), parse_line(allocator, "xtwone3four"));
    try t.expectEqual(@as(u32, 42), parse_line(allocator, "4nineeightseven2"));
    try t.expectEqual(@as(u32, 14), parse_line(allocator, "zoneight234"));
    try t.expectEqual(@as(u32, 76), parse_line(allocator, "7pqrstsixteen"));
}
