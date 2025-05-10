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
};
