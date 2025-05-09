const std = @import("std");

pub const Location = struct {
    offset: usize,
    line: usize,
    column: usize,
};

pub const Span = struct {
    start: Location,
    end: Location,

    pub fn with_size(start: Location, size: usize) Span {
        return Span{
            .start = start,
            .end = Location{
                .offset = start.offset + size,
                .line = start.line,
                .column = start.column + size,
            },
        };
    }
};
