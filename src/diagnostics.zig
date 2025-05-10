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
