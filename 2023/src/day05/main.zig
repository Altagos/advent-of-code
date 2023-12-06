const std = @import("std");
const parseInt = std.fmt.parseInt;

const tracer = @import("tracer");

const build_options = @import("build_options");
const util = @import("util");

pub const std_options = util.std_options;
pub const tracer_impl = if (build_options.trace) tracer.spall else tracer.none;

const data = @embedFile("data.txt");

const AlmanacParserConfig = struct {
    enable_ranges_of_seed_numbers: bool = false,
};

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

const Seeds = struct {
    pub const SeedRange = struct {
        start: u64,
        length: u64,

        fn contains(self: *const SeedRange, n: u64) bool {
            return self.start <= n and n < self.start + self.length;
        }
    };

    ranges: []SeedRange,

    pub fn from_string(allocator: std.mem.Allocator, section: []const u8, config: AlmanacParserConfig) !Seeds {
        var ranges = std.ArrayList(SeedRange).init(allocator);
        defer ranges.deinit();

        var iter = std.mem.splitAny(u8, section, " ");
        if (std.mem.eql(u8, iter.first(), "seeds:")) {
            if (config.enable_ranges_of_seed_numbers) {
                var start: u64 = 0;
                var idx: u64 = 0;
                while (iter.next()) |r| : (idx += 1) {
                    const int = try parseInt(u64, r, 10);
                    if (idx % 2 == 0) {
                        start = int;
                    } else {
                        try ranges.append(.{
                            .start = start,
                            .length = int,
                        });
                    }
                }
            } else {
                while (iter.next()) |r| {
                    const int = try parseInt(u64, r, 10);
                    try ranges.append(.{
                        .start = int,
                        .length = 1,
                    });
                }
            }
        } else {
            return error.MissingSeedsSection;
        }

        return .{ .ranges = try ranges.toOwnedSlice() };
    }

    fn iterator(self: *Seeds) SeedIterator {
        return SeedIterator{
            .ranges = self.ranges,
            .last_value = self.ranges[0].start - 1,
        };
    }
};

const SeedIterator = struct {
    ranges: []Seeds.SeedRange,
    last_value: u64,
    index: usize = 0,

    fn next(self: *SeedIterator) ?u64 {
        if (self.index >= self.ranges.len) {
            return null;
        }

        const index = self.index;
        const range = self.ranges[index];

        self.last_value += 1;
        if (!range.contains(self.last_value)) {
            self.index += 1;
            if (self.index >= self.ranges.len) {
                return null;
            }

            self.last_value = self.ranges[self.index].start;
        }

        return self.last_value;
    }
};

const Almanac = struct {
    seeds: Seeds,
    maps: std.AutoHashMap(SectionType, std.ArrayList(Range)),

    pub fn deinit(self: *Almanac) void {
        var iter = self.maps.iterator();
        while (iter.next()) |map| {
            map.value_ptr.deinit();
        }
        self.maps.deinit();
    }

    pub fn parse(allocator: std.mem.Allocator, input: []const u8, config: AlmanacParserConfig) !*Almanac {
        const t = tracer.trace(@src(), "Almanac::parse", .{});
        defer t.end();

        var almanac: *Almanac = try allocator.create(Almanac);

        var maps = std.AutoHashMap(SectionType, std.ArrayList(Range)).init(allocator);
        defer maps.deinit();

        var sections = std.mem.splitSequence(u8, input, "\n\n");
        var idx: u64 = 0;
        while (sections.next()) |section| : (idx += 1) {
            switch (idx) {
                0 => {
                    almanac.seeds = try Seeds.from_string(allocator, section, config);
                },
                else => {
                    var line_iter = std.mem.tokenizeScalar(
                        u8,
                        section,
                        '\n',
                    );

                    const title_line = line_iter.next() orelse return error.MissingSctionTitle;
                    var title_iter = std.mem.splitAny(
                        u8,
                        title_line,
                        " ",
                    );
                    const section_title = std.meta.stringToEnum(
                        SectionType,
                        title_iter.first(),
                    ) orelse return error.UnknownSction;

                    var range_list = std.ArrayList(Range).init(allocator);
                    defer range_list.deinit();

                    while (line_iter.next()) |line| {
                        const range = try Range.from_string(line);
                        try range_list.append(range);
                    }

                    try maps.put(section_title, try range_list.clone());
                },
            }
        }

        almanac.maps = try maps.clone();

        return almanac;
    }

    fn print(self: *Almanac) void {
        std.debug.print("Almanac\nseeds:", .{});

        var seed_iterator = self.seeds.iterator();
        while (seed_iterator.next()) |seed| {
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

    fn find_seed_with_lowest_location(self: *Almanac) u64 {
        const t = tracer.trace(@src(), "Find Seed With Lowest Location", .{});
        defer t.end();

        var lowest_location = @as(u64, @bitCast(std.math.inf(f64)));

        var seed_iter = self.seeds.iterator();
        while (seed_iter.next()) |seed| {
            const t_seed = tracer.trace(@src(), "Seed: {d}", .{seed});
            defer t_seed.end();

            var value = seed;
            var current_section = SectionType.@"seed-to-soil";
            var next_section = TRAVERSAL_MAP[@intFromEnum(current_section)].@"1";

            std.log.debug("{}", .{value});

            while (next_section) |next| {
                const t_section = tracer.trace(@src(), "Seed: {d} > Section: {s}", .{ seed, current_section.to_string() });
                defer t_section.end();

                const map = self.maps.get(current_section).?;
                value = Range.dest_in_list(map, value);
                std.log.debug(" {s} {}", .{ current_section.to_string(), value });

                current_section = next;
                next_section = TRAVERSAL_MAP[@intFromEnum(current_section)].@"1";
            }

            const map = self.maps.get(current_section).?;
            value = Range.dest_in_list(map, value);
            std.log.debug(" {s} {}\n", .{ current_section.to_string(), value });

            lowest_location = @min(lowest_location, value);
        }

        return lowest_location;
    }
};

pub fn part1(input: []const u8) !u64 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var almanac = try Almanac.parse(allocator, input, .{});
    defer almanac.deinit();
    // almanac.print();

    return almanac.find_seed_with_lowest_location();
}

pub fn part2(input: []const u8) !u64 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var almanac = try Almanac.parse(allocator, input, .{
        .enable_ranges_of_seed_numbers = true,
    });
    defer almanac.deinit();

    return almanac.find_seed_with_lowest_location();
}

pub fn main() !void {
    try tracer.init();
    defer tracer.deinit();

    try tracer.init_thread();
    defer tracer.deinit_thread();

    const t_part1 = tracer.trace(@src(), "Part 1", .{});

    const result_part1 = try part1(data);
    std.log.info("result part 1: {}", .{result_part1});

    t_part1.end();

    const t_part2 = tracer.trace(@src(), "Part 2", .{});

    const result_part2 = try part2(data);
    std.log.info("result part 2: {}", .{result_part2});

    t_part2.end();
}

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

test "test example part 1" {
    const t = std.testing;

    try tracer.init_thread();
    defer tracer.deinit_thread();

    const t_part1 = tracer.trace(@src(), "Part 1", .{});
    defer t_part1.end();

    const result = try part1(example_data);
    try t.expectEqual(@as(u64, 35), result);
}

test "test example part 2" {
    const t = std.testing;

    const result = try part2(example_data);
    try t.expectEqual(@as(u64, 46), result);
}
