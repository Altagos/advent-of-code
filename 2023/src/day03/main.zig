const std = @import("std");
const util = @import("util");

pub const std_options = util.std_options;

const data = @embedFile("data.txt");

const GridItem = union(enum) {
    number: struct {
        n: usize,
        has_neigbour: bool,
    },
    symbol: []const u8,
    dot: void,

    pub fn from_char(input: []const u8) GridItem {
        if (std.mem.eql(u8, input, ".")) {
            return GridItem{ .dot = {} };
        }

        return GridItem{
            .number = .{
                .n = std.fmt.parseInt(usize, input, 10) catch return GridItem{ .symbol = input },
                .has_neigbour = false, // has to be false, because we have no context of the other cells, around this one
            },
        };
    }
};

const Grid = struct {
    allocator: std.mem.Allocator,

    inner: []GridItem,
    width: usize,
    height: usize,

    pub fn init(allocator: std.mem.Allocator, comptime width: usize, comptime height: usize) !*Grid {
        const grid = try allocator.create(Grid);
        grid.allocator = allocator;

        const inner = try grid.allocator.create([width * height]GridItem);
        grid.inner = inner;
        grid.width = width;
        grid.height = height;

        return grid;
    }

    pub fn deinit(self: *Grid) void {
        self.allocator.destroy(self.inner);
    }

    pub fn set(self: *Grid, x: usize, y: usize, item: GridItem) void {
        const grid_pos = y * self.width + x;
        self.inner[grid_pos] = item;
    }

    pub fn get(self: *Grid, x: usize, y: usize) GridItem {
        const grid_pos = y * self.width + x;
        return self.inner[grid_pos];
    }

    pub fn get_ref(self: *Grid, x: usize, y: usize) *GridItem {
        const grid_pos = y * self.width + x;
        return &self.inner[grid_pos];
    }

    pub fn print(self: *Grid) void {
        std.debug.print("{any}", .{self.inner});
    }
};

pub fn part1(input: []const u8) usize {
    _ = input;

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const grid = Grid.init(allocator, 4, 5) catch return 0;

    grid.set(2, 3, GridItem.from_char("*"));

    const item = grid.get_ref(1, 1);
    item.* = GridItem{ .number = .{ .n = 2, .has_neigbour = true } };
    std.debug.print("{any}", .{grid.get(1, 1)});

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

test "test example part 1" {
    const t = std.testing;

    const example_data =
        \\467..114..
        \\...*......
        \\..35..633.
        \\......#...
        \\617*......
        \\.....+.58.
        \\..592.....
        \\......755.
        \\...$.*....
        \\.664.598..
    ;

    const result = part1(example_data);
    try t.expectEqual(@as(usize, 0), result);
}

test "test example part 2" {}
