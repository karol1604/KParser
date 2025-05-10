const std = @import("std");
const token = @import("tokens.zig");
const Token = token.Token;

pub const LexerErrorType = error{
    InvalidCharacter,
    InvalidNumber,
};

const RESET = "\x1b[0m";
const RED = "\x1b[31m";

pub const LexerError = struct {
    type: LexerErrorType,
    token: ?Token,
    message: ?[]const u8,
    source: []const u8,

    pub fn format(self: LexerError, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        try writer.print("Parse Error ({any}): ", .{self.type});
        if (self.message) |msg| {
            try writer.print("'{s}' ", .{msg});
        }
        if (self.token) |tok| {
            try writer.print("near token '{s}'\n\n", .{tok});
            try writer.print("{s}{s}{s}{s}{s}\n", .{ self.source[0..tok.span.start], RED, self.source[tok.span.start .. tok.span.start + tok.span.size], RESET, self.source[tok.span.start + tok.span.size ..] });
        }
    }
};

pub const LexerResult = union(enum) {
    ok: void,
    err: LexerError,
};
