const std = @import("std");

pub const std_options = @import("util/std_options.zig");

pub const parseFlaot = std.fmt.parseFloat;
pub const parseInt = std.fmt.parseInt;
pub const parseIntSizeSuffix = std.fmt.parseIntSizeSuffix;
pub const parseUnsigned = std.fmt.parseUnsigned;

pub const replaceOwned = std.mem.replaceOwned;

pub const splitAny = std.mem.splitAny;
pub const splitBackwardsAny = std.mem.splitBackwardsAny;
pub const splitScalar = std.mem.splitScalar;
pub const splitBackwardsScalar = std.mem.splitBackwardsScalar;
pub const splitSequence = std.mem.splitSequence;
pub const splitBackwardsSequence = std.mem.splitBackwardsSequence;

pub const stringToEnum = std.meta.stringToEnum;

pub const tokenizeAny = std.mem.tokenizeAny;
pub const tokenizeScalar = std.mem.tokenizeScalar;
pub const tokenizeSequence = std.mem.tokenizeSequence;

/// Returns an iterator over the lines of a string.
pub fn lineIterator(buffer: []const u8) std.mem.SplitIterator(u8, .sequence) {
    return splitSequence(u8, buffer, "\n");
}

pub fn lineIteratorTokens(buffer: []const u8) std.mem.TokenIterator(u8, .scalar) {
    return tokenizeScalar(u8, buffer, '\n');
}
