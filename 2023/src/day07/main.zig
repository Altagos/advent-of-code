const std = @import("std");
const util = @import("util");

pub const std_options = util.std_options;

const data = @embedFile("data.txt");

const HandType = enum(u64) {
    five_of_a_kind = 6,
    four_of_a_kind = 5,
    full_house = 4,
    three_of_a_kind = 3,
    two_pair = 2,
    one_pair = 1,
    high_card = 0,

    pub const ParseResult = struct { HandType, ?bool }; // Hand type, contains joker(s)

    pub fn from_string(input: []const u8, joker_rule: bool) !ParseResult {
        var num_a: u16 = 0;
        var num_b: u16 = 0;
        var num_c: u16 = 0;
        var num_d: u16 = 0;
        var num_e: u16 = 0;

        var num_jokers: u16 = 0;

        const num_ptrs = [5]*u16{ &num_a, &num_b, &num_c, &num_d, &num_e };
        for (input, num_ptrs) |char, num| {
            var num_occurences: u16 = 0;

            for (0..5) |i| {
                if (joker_rule and char == 'J') {
                    num_jokers += 1;
                } else {
                    num_occurences += if (char == input[i]) 1 else 0;
                }
            }

            num.* = if (joker_rule and num_occurences == 0) 1 else num_occurences;
        }

        var hand_type: HandType = switch (num_a * num_b * num_c * num_d * num_e) {
            5 * 5 * 5 * 5 * 5 => .five_of_a_kind,
            4 * 4 * 4 * 4 * 1 => .four_of_a_kind,
            3 * 3 * 3 * 2 * 2 => .full_house,
            3 * 3 * 3 * 1 * 1 => .three_of_a_kind,
            2 * 2 * 2 * 2 * 1 => .two_pair,
            2 * 2 * 1 * 1 * 1 => .one_pair,
            1 * 1 * 1 * 1 * 1 => .high_card,
            else => return error.UnkownCombination,
        };

        num_jokers /= 5;
        for (0..num_jokers) |_| {
            if (hand_type != .five_of_a_kind) {
                hand_type = switch (hand_type) {
                    .five_of_a_kind => .five_of_a_kind,
                    .four_of_a_kind => .five_of_a_kind,
                    .full_house => .four_of_a_kind,
                    .three_of_a_kind => .four_of_a_kind,
                    .two_pair => .full_house,
                    .one_pair => .three_of_a_kind,
                    .high_card => .one_pair,
                };
            }
        }

        const joker_result = if (!joker_rule) null else num_jokers > 0;
        return ParseResult{ hand_type, joker_result };
    }
};

const Hand = struct {
    bid: u64,
    hand_input: []const u8,
    hand_type: HandType,
    input: []const u8,
    jokers: ?bool,

    pub fn init(allocator: std.mem.Allocator, input: []const u8, joker_rule: bool) !Hand {
        var tokens = util.tokenizeScalar(u8, input, ' ');
        const hand = tokens.next().?;
        const hand_input = try util.replaceOwned(u8, allocator, hand, " ", "");
        const bid = try util.parseUnsigned(u64, tokens.next().?, 0);

        const hand_type, const jokers = try HandType.from_string(hand, joker_rule);

        return .{
            .input = input,
            .bid = bid,
            .hand_input = hand_input,
            .hand_type = hand_type,
            .jokers = jokers,
        };
    }

    pub fn compareLessThan(ctx: void, lhs: Hand, rhs: Hand) bool {
        _ = ctx;

        const ltype = @intFromEnum(lhs.hand_type);
        const rtype = @intFromEnum(rhs.hand_type);

        if (ltype != rtype) {
            return ltype < rtype;
        } else {
            for (lhs.hand_input, rhs.hand_input) |lc, rc| {
                const lval = getCardValue(lc, if (lhs.jokers) |_| true else false);
                const rval = getCardValue(rc, if (rhs.jokers) |_| true else false);
                if (lval != rval) return lval < rval;
            }
        }
        unreachable;
    }

    fn print(self: Hand) void {
        std.debug.print("Hand {{ type: {}, bid: {}, input: \"{s}\" }}\n", .{ self.hand_type, self.bid, self.input });
    }

    fn getCardValue(b: u8, joker_rule: bool) u8 {
        return switch (b) {
            '2'...'9' => return @intCast(b - '0'),
            'T' => return 10,
            'J' => return if (joker_rule) 1 else 11,
            'Q' => return 12,
            'K' => return 13,
            'A' => return 14,
            else => return 0,
        };
    }
};

pub fn part1(allocator: std.mem.Allocator, input: []const u8) !u64 {
    var hands = std.ArrayList(Hand).init(allocator);
    defer hands.deinit();

    var lines = util.lineIterator(input);
    while (lines.next()) |l| {
        try hands.append(try Hand.init(allocator, l, false));
    }

    const sorted = try hands.toOwnedSlice();
    std.mem.sort(Hand, sorted, {}, Hand.compareLessThan);

    var result: u64 = 0;
    for (sorted, 1..) |hand, rank| {
        // std.debug.print("rank: {}, hand: ", .{rank});
        // hand.print();
        result += hand.bid * rank;
    }

    return result;
}

pub fn part2(allocator: std.mem.Allocator, input: []const u8) !u64 {
    var hands = std.ArrayList(Hand).init(allocator);
    defer hands.deinit();

    var lines = util.lineIterator(input);
    while (lines.next()) |l| {
        try hands.append(try Hand.init(allocator, l, true));
    }

    const sorted = try hands.toOwnedSlice();
    std.mem.sort(Hand, sorted, {}, Hand.compareLessThan);

    var result: u64 = 0;
    for (sorted, 1..) |hand, rank| {
        // std.debug.print("rank: {}, hand: ", .{rank});
        // hand.print();
        result += hand.bid * rank;
    }

    return result;
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const result_part1 = try part1(allocator, data);
    std.log.info("result part 1: {}", .{result_part1});

    const result_part2 = try part2(allocator, data);
    std.log.info("result part 2: {}", .{result_part2});
}

const example_data =
    \\32T3K 765
    \\T55J5 684
    \\KK677 28
    \\KTJJT 220
    \\QQQJA 483
; // 32T3K 34Q6Q KK677 6664J T55J5 QQQJA KTJJT AAAJJ

test "test example part 1" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const result = try part1(allocator, example_data);
    try std.testing.expectEqual(@as(u64, 6440), result);
}

test "test example part 2" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const result = try part2(allocator, example_data);
    try std.testing.expectEqual(@as(u64, 5905), result);
}

test "parse hand kinds" {
    const t = std.testing;

    try t.expectEqual(HandType.ParseResult{ HandType.five_of_a_kind, null }, try HandType.from_string("AAAAA", false));
    try t.expectEqual(HandType.ParseResult{ HandType.four_of_a_kind, null }, try HandType.from_string("AA9AA", false));
    try t.expectEqual(HandType.ParseResult{ HandType.full_house, null }, try HandType.from_string("23332", false));
    try t.expectEqual(HandType.ParseResult{ HandType.three_of_a_kind, null }, try HandType.from_string("TTT98", false));
    try t.expectEqual(HandType.ParseResult{ HandType.two_pair, null }, try HandType.from_string("23432", false));
    try t.expectEqual(HandType.ParseResult{ HandType.one_pair, null }, try HandType.from_string("A23A4", false));
    try t.expectEqual(HandType.ParseResult{ HandType.high_card, null }, try HandType.from_string("23456", false));
}
