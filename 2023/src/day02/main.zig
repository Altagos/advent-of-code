const std = @import("std");
const util = @import("util");

pub const std_options = util.std_options;

const data = @embedFile("data.txt");

const Round = struct {
    pub const Error = error{ EmptyRoundString, MissingNumber, InvalidRoundString };

    red: usize,
    green: usize,
    blue: usize,

    pub fn init() Round {
        return .{ .red = 0, .green = 0, .blue = 0 };
    }

    pub fn parse(input: []const u8) Round.Error!Round {
        var round = Round.init();

        var iter = std.mem.tokenize(u8, input, ",");

        while (iter.next()) |x| {
            var color_number = std.mem.splitBackwardsScalar(u8, x, ' ');
            const color: []const u8 = c: {
                while (color_number.next()) |col| {
                    if (!std.mem.allEqual(u8, col, ' ')) {
                        break :c col;
                    }
                }
                return error.EmptyRoundString;
            };

            const number = n: {
                while (color_number.next()) |num| {
                    if (!std.mem.allEqual(u8, num, ' ')) {
                        break :n std.fmt.parseInt(usize, num, 10) catch continue;
                    }
                }
                return error.MissingNumber;
            };

            if (std.mem.endsWith(u8, color, "d")) {
                round.red += number;
            } else if (std.mem.endsWith(u8, color, "n")) {
                round.green += number;
            } else if (std.mem.endsWith(u8, color, "e")) {
                round.blue += number;
            } else {
                return error.InvalidRoundString;
            }
        }

        return round;
    }

    pub fn test_max_eql(self: *const Round, max: Round) bool {
        return (self.red <= max.red) and (self.green <= max.green) and (self.blue <= max.blue);
    }

    pub fn test_multiple_part1(rounds: *const std.ArrayList(Round), max: Round) bool {
        var ok = true;

        for (rounds.items) |r| {
            ok = ok and (r.red <= max.red) and (r.green <= max.green) and (r.blue <= max.blue);
        }

        return ok;
    }

    pub fn test_multiple_part2(rounds: *const std.ArrayList(Round)) Round {
        var ok = Round.init();

        for (rounds.items) |r| {
            ok.red = @max(ok.red, r.red);
            ok.green = @max(ok.green, r.green);
            ok.blue = @max(ok.blue, r.blue);
        }

        return ok;
    }
};

const Game = struct {
    id: usize,
    rounds: std.ArrayList(Round),

    pub fn init(allocator: std.mem.Allocator) Game {
        return .{ .id = 0, .rounds = std.ArrayList(Round).init(allocator) };
    }

    pub fn deinit(self: *Game) void {
        self.rounds.deinit();
    }

    pub fn parse(game: *Game, input: []const u8) !Game {
        var input_iter = std.mem.tokenize(u8, input, ":");
        const game_id_string = input_iter.next() orelse return error.InvalidInput;
        const game_rounds_string = input_iter.next() orelse return error.InvalidInput;

        // Game ID
        game.id = try std.fmt.parseInt(usize, game_id_string[5..], 10);

        // Game rounds
        var rounds_iter = std.mem.tokenize(u8, game_rounds_string, ";");
        while (rounds_iter.next()) |s| {
            try game.rounds.append(Round.parse(s) catch Round.init());
        }

        return game.*;
    }
};

pub fn part1(input: []const u8) usize {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var total: usize = 0;

    var iter = std.mem.splitSequence(u8, input, "\n");
    while (iter.next()) |line| {
        var game = Game.init(allocator);
        defer game.deinit();

        game = game.parse(line) catch {
            std.log.err("Invalid input: {s}\n", .{line});
            return 0;
        };

        if (Round.test_multiple_part1(&game.rounds, Round{ .red = 12, .green = 13, .blue = 14 })) {
            total += game.id;
            std.log.debug("game {} is possible", .{game.id});
        }

        // std.debug.print("\n\n", .{});
    }

    return total;
}

pub fn part2(input: []const u8) usize {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var total: usize = 0;

    var iter = std.mem.splitSequence(u8, input, "\n");
    while (iter.next()) |line| {
        var game = Game.init(allocator);
        defer game.deinit();

        game = game.parse(line) catch {
            std.log.err("Invalid input: {s}\n", .{line});
            return 0;
        };

        const result = Round.test_multiple_part2(&game.rounds);

        total += result.red * result.green * result.blue;

        // std.debug.print("\n\n", .{});
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

test "test Round parser" {
    const t = std.testing;

    try t.expectEqual(Round{ .red = 0, .green = 0, .blue = 0 }, try Round.parse(""));
    try t.expectError(Round.Error.EmptyRoundString, Round.parse(" "));
    try t.expectEqual(Round{ .red = 4, .green = 0, .blue = 3 }, try Round.parse(" 3 blue, 4 red"));
    try t.expectEqual(Round{ .red = 3, .green = 5, .blue = 4 }, try Round.parse("3 red, 5 green, 4 blue"));
}

// test "test Game parser" {
//     const t = std.testing;

//     const game = Game.init(t.allocator);
//     _ = game;
//     try t.expectError(error.InvalidInput, game.parse(""));
//     try t.expectError(error.InvalidInput, game.parse(" "));
//     try t.expectEqual(Game{ .id = 1, .rounds = [3]Round{
//         Round{ .red = 4, .green = 0, .blue = 3 },
//         Round{ .red = 1, .green = 2, .blue = 6 },
//         Round{ .red = 0, .green = 2, .blue = 0 },
//     } }, try Game.parse("Game 1: 3 blue, 4 red; 1 red, 2 green, 6 blue; 2 green"));
// }

test "test example part 1" {
    const t = std.testing;

    const example_input =
        \\Game 1: 3 blue, 4 red; 1 red, 2 green, 6 blue; 2 green
        \\Game 2: 1 blue, 2 green; 3 green, 4 blue, 1 red; 1 green, 1 blue
        \\Game 3: 8 green, 6 blue, 20 red; 5 blue, 4 red, 13 green; 5 green, 1 red
        \\Game 4: 1 green, 3 red, 6 blue; 3 green, 6 red; 3 green, 15 blue, 14 red
        \\Game 5: 6 red, 1 blue, 3 green; 2 blue, 1 red, 2 green
    ;

    try t.expectEqual(@as(usize, 8), part1(example_input));
}

test "test example part 2" {}
