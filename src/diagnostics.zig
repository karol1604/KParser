const std = @import("std");
const span = @import("span.zig");

const Span = span.Span;

pub const ReportKind = enum {
    LexerError,
    ParserError,
    TypeError,
    RuntimeError,
};

pub const Report = struct {
    kind: ReportKind,
    message: []const u8,
    span: Span,

    pub fn err(source: []const u8, mainMessage: []const u8, detailedMessages: [2][]const u8, parentSpan: Span, problematicSpans: []const Span) void {
        const RESET = "\x1b[0m";
        const RED = "\x1b[31m";

        const parentStart = parentSpan.start.offset;
        const parentEnd = parentSpan.end.offset;

        std.debug.print("{s}error:{s} {s}\n", .{ RED, RESET, mainMessage });

        for (detailedMessages, problematicSpans) |detailedMessage, problematicSpan| {
            const start = problematicSpan.start.offset;
            const end = problematicSpan.end.offset;
            const lineEnd = findLineEnd(source, end);

            std.debug.print("{s}", .{source[parentStart..start]});
            std.debug.print("{s}{s}{s}", .{ RED, source[start..end], RESET });
            std.debug.print("{s} <-- {s}", .{ source[end..lineEnd], detailedMessage });
            std.debug.print("{s}\n", .{source[lineEnd..parentEnd]});
        }

        // std.debug.print("{s}", .{source[parentStart..problematicSpans[0].start.offset]});
        // std.debug.print("{s}{s}{s}", .{ RED, source[problematicSpans[0].start.offset..problematicSpans[0].end.offset], RESET });
        // const lineEnd1 = findLineEnd(source, problematicSpans[0].end.offset);
        // std.debug.print("{s} <-- {s}", .{ source[problematicSpans[0].end.offset..lineEnd1], detailedMessages[0] });
        //
        // std.debug.print("{s}", .{source[lineEnd1..problematicSpans[1].start.offset]});
        // std.debug.print("{s}{s}{s}", .{ RED, source[problematicSpans[1].start.offset..problematicSpans[1].end.offset], RESET });
        // const lineEnd2 = findLineEnd(source, problematicSpans[1].end.offset);
        // std.debug.print("{s} <-- {s}", .{ source[problematicSpans[1].end.offset..lineEnd2], detailedMessages[1] });
        // std.debug.print("{s}\n", .{source[lineEnd2..parentEnd]});
    }
};

// IDEAS
fn findLineEnd(source: []const u8, start: usize) usize {
    var i = start;
    while (i < source.len) : (i += 1) {
        if (source[i] == '\n') {
            return i;
        }
    }
    return source.len;
}
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
