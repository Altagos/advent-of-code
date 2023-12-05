const std = @import("std");
const parseInt = std.fmt.parseInt;

const util = @import("util");

pub const std_options = util.std_options;

const data = @embedFile("data.txt");

const Range = struct {
    start_dest: u64,
    start_source: u64,
    length: u64,

    pub fn from_string(str: []const u8) !Range {
        var iter = std.mem.splitAny(u8, str, " ");

        return Range{
            .start_dest = try parseInt(u64, iter.next() orelse return error.InvalidFormat, 0),
            .start_source = try parseInt(u64, iter.next() orelse return error.InvalidFormat, 0),
            .length = try parseInt(u64, iter.next() orelse return error.InvalidFormat, 0),
        };
    }

    pub fn print(self: *Range) void {
        std.debug.print("{d} {d} {d}\n", .{ self.start_dest, self.start_source, self.length });
    }

    pub fn dest(self: *const Range, source: u64) ?u64 {
        if (self.start_source <= source and source < self.start_source + self.length) {
            const dist = source - self.start_source;
            return self.start_dest + dist;
        } else {
            return null;
        }
    }

    pub fn dest_in_list(ranges: std.ArrayList(Range), a: u64) u64 {
        for (ranges.items) |range| {
            if (range.dest(a)) |d| {
                return d;
            }
        }
        return a;
    }
};

const SectionType = enum(u8) {
    seeds,
    @"seed-to-soil",
    @"soil-to-fertilizer",
    @"fertilizer-to-water",
    @"water-to-light",
    @"light-to-temperature",
    @"temperature-to-humidity",
    @"humidity-to-location",

    pub fn to_string(self: *SectionType) []const u8 {
        switch (self.*) {
            .seeds => return "seeds",
            .@"seed-to-soil" => return "seed-to-soil",
            .@"soil-to-fertilizer" => return "soil-to-fertilizer",
            .@"fertilizer-to-water" => return "fertilizer-to-water",
            .@"water-to-light" => return "water-to-light",
            .@"light-to-temperature" => return "light-to-temperature",
            .@"temperature-to-humidity" => return "temperature-to-humidity",
            .@"humidity-to-location" => return "humidity-to-location",
        }
    }
};

const TraversalMapItem = struct { SectionType, ?SectionType };
const TRAVERSAL_MAP: [8]TraversalMapItem = .{
    .{ SectionType.seeds, SectionType.@"seed-to-soil" },
    .{ SectionType.@"seed-to-soil", SectionType.@"soil-to-fertilizer" },
    .{ SectionType.@"soil-to-fertilizer", SectionType.@"fertilizer-to-water" },
    .{ SectionType.@"fertilizer-to-water", SectionType.@"water-to-light" },
    .{ SectionType.@"water-to-light", SectionType.@"light-to-temperature" },
    .{ SectionType.@"light-to-temperature", SectionType.@"temperature-to-humidity" },
    .{ SectionType.@"temperature-to-humidity", SectionType.@"humidity-to-location" },
    .{ SectionType.@"humidity-to-location", null },
};

const Almanac = struct {
    seeds: []u64,
    maps: std.AutoHashMap(SectionType, std.ArrayList(Range)),

    pub fn parse(allocator: std.mem.Allocator, input: []const u8) !*Almanac {
        var almanac: *Almanac = try allocator.create(Almanac);
        // almanac.seeds = (try allocator.create(@TypeOf(almanac.seeds))).init();

        var seeds = std.ArrayList(u64).init(allocator);
        defer seeds.deinit();

        var maps = std.AutoHashMap(SectionType, std.ArrayList(Range)).init(allocator);
        defer maps.deinit();

        var sections = std.mem.splitSequence(u8, input, "\n\n");
        var idx: u64 = 0;
        while (sections.next()) |section| : (idx += 1) {
            switch (idx) {
                0 => {
                    var iter = std.mem.splitAny(u8, section, " ");
                    if (std.mem.eql(u8, iter.first(), "seeds:")) {
                        // std.debug.print("Seeds:\n", .{});
                        while (iter.next()) |r| {
                            const seed = try parseInt(u64, r, 10);
                            // std.debug.print("{s}: {} - {d}: {}\n", .{ r, @TypeOf(r), seed, @TypeOf(seed) });
                            try seeds.append(seed);
                        }
                    } else {
                        return error.MissingSeedsSection;
                    }
                },
                else => {
                    var line_iter = std.mem.tokenizeScalar(u8, section, '\n');

                    const title_line = line_iter.next() orelse return error.MissingSctionTitle;
                    var title_iter = std.mem.splitAny(u8, title_line, " ");
                    const title = title_iter.first();
                    // std.debug.print("'{s}'\n", .{title});
                    const section_title = std.meta.stringToEnum(SectionType, title) orelse return error.UnknownSction;

                    var range_list = std.ArrayList(Range).init(allocator);
                    defer range_list.deinit();

                    while (line_iter.next()) |line| {
                        const range = try Range.from_string(line);
                        // std.debug.print("{s}: {} - {}: {}\n", .{ line, @TypeOf(line), range, @TypeOf(range) });
                        try range_list.append(range);
                    }

                    try maps.put(section_title, try range_list.clone());
                },
            }
        }

        almanac.seeds = try seeds.toOwnedSlice();
        almanac.maps = try maps.clone();

        return almanac;
    }

    fn print(self: *Almanac) void {
        std.debug.print("Almanac\nseeds:", .{});

        for (self.seeds) |seed| {
            std.debug.print(" {d}", .{seed});
        }

        std.debug.print("\n\n", .{});

        var maps_iterator = self.maps.iterator();
        while (maps_iterator.next()) |map| {
            std.debug.print("{s} map:\n", .{map.key_ptr.to_string()});

            for (map.value_ptr.items) |*range| {
                range.print();
            }

            std.debug.print("\n", .{});
        }
    }
};

pub fn part1(input: []const u8) !u64 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const almanac = try Almanac.parse(allocator, input);
    almanac.print();

    var lowest_location = @as(u64, @bitCast(std.math.inf(f64)));

    for (almanac.seeds) |seed| {
        var value = seed;
        var current_section = SectionType.@"seed-to-soil";

        std.log.debug("{}", .{value});

        while (TRAVERSAL_MAP[@intFromEnum(current_section)].@"1") |next_section| {
            const map = almanac.maps.get(current_section).?;
            value = Range.dest_in_list(map, value);
            std.log.debug(" {s} {}", .{ current_section.to_string(), value });

            current_section = next_section;
        }

        const map = almanac.maps.get(current_section).?;
        value = Range.dest_in_list(map, value);
        std.log.debug(" {s} {}\n", .{ current_section.to_string(), value });

        lowest_location = @min(lowest_location, value);
    }

    return lowest_location;
}

pub fn part2(input: []const u8) u64 {
    _ = input;
    return 0;
}

pub fn main() !void {
    // std.log.info("processing part 1: {s}", .{data});
    const result_part1 = try part1(data);
    std.log.info("result part 1: {}", .{result_part1});

    const result_part2 = part2(data);
    std.log.info("result part 2: {}", .{result_part2});
}

test "test example part 1" {
    const t = std.testing;

    const example_data =
        \\seeds: 79 14 55 13
        \\
        \\seed-to-soil map:
        \\50 98 2
        \\52 50 48
        \\
        \\soil-to-fertilizer map:
        \\0 15 37
        \\37 52 2
        \\39 0 15
        \\
        \\fertilizer-to-water map:
        \\49 53 8
        \\0 11 42
        \\42 0 7
        \\57 7 4
        \\
        \\water-to-light map:
        \\88 18 7
        \\18 25 70
        \\
        \\light-to-temperature map:
        \\45 77 23
        \\81 45 19
        \\68 64 13
        \\
        \\temperature-to-humidity map:
        \\0 69 1
        \\1 0 69
        \\
        \\humidity-to-location map:
        \\60 56 37
        \\56 93 4
    ;

    const result = try part1(example_data);
    try t.expectEqual(@as(u64, 35), result);
}

test "test example part 2" {}
