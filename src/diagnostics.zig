const std = @import("std");
const span = @import("span.zig");

const Span = span.Span;

pub const DiagnosticKind = enum {
    LexerError,
    ParserError,
    TypeError,
    RuntimeError,
};

pub const Diagnostic = struct {
    kind: DiagnosticKind,
    message: []const u8,
    span: Span,
};

// IDEAS
// fn findLineEnd(self: *Checker, start: usize) usize {
//     var i = start;
//     while (i < self.source.len) : (i += 1) {
//         if (self.source[i] == '\n') {
//             return i;
//         }
//     }
//     return self.source.len;
// }
//
// fn printErroredSourceSlice(self: *Checker, span: Span) void {
//     const RESET = "\x1b[0m";
//     const RED = "\x1b[31m";
//
//     const start = span.start.offset;
//     const end = span.end.offset;
//     const lineEnd = self.findLineEnd(span.end.offset);
//
//     std.debug.print("{s}", .{self.source[0..start]});
//     const sourceSlice = self.source[start..end];
//     std.debug.print("{s}{s}{s}", .{ RED, sourceSlice, RESET });
//     std.debug.print("{s} <-- occurs here", .{self.source[end..lineEnd]});
//     std.debug.print("{s}\n", .{self.source[end..]});
//
//     // const lineStart = utils.findLineStart(sourceSlice, start);
//     // const lineEnd = utils.findLineEnd(sourceSlice, end);
//     //
//     // std.debug.print("Line slice: `{s}`\n", .{self.source[lineStart..lineEnd]});
// }
