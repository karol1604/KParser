const std = @import("std");

pub const Location = struct {
    offset: usize,
    line: usize,
    column: usize,
};

pub const Span = struct {
    start: Location,
    end: Location,

    pub fn sum(left: Span, right: Span) Span {
        return Span{
            .start = left.start,
            .end = right.end,
        };
    }

    pub fn format(self: Span, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        try writer.print("({d}..{d}) on line {d} (offset: [{d}..{d}])", .{
            self.start.column,
            self.end.column,
            self.start.line,
            self.start.offset,
            self.end.offset,
        });
    }
};
