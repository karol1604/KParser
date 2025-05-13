const std = @import("std");
const span = @import("span.zig");

const Span = span.Span;

pub const Statement = struct {
    kind: StatementKind,
    span: Span,
};

pub const StatementKind = union(enum) {
    ExpressionStatement: *const Expression,

    LetStatement: struct {
        name: []const u8,
        value: *const Expression,
    },

    ReturnStatement: struct {
        implicit: bool,
        value: *const Expression,
    },

    // etc
};

pub const Expression = struct {
    kind: ExpressionKind,
    span: Span,
};

pub const ExpressionKind = union(enum) {
    IntLiteral: i64,

    Identifier: []const u8,

    BoolLiteral: bool,

    Unary: struct {
        operator: UnaryOperator,
        right: *const Expression,
    },

    Binary: struct {
        left: *const Expression,
        operator: BinaryOperator,
        right: *const Expression,
    },
};

pub const UnaryOperator = union(enum) {
    Plus,
    Minus,
    Not,
};

pub const BinaryOperator = union(enum) {
    Plus,
    Minus,
    Divide,
    Multiply,
    Exponent,

    Equal,
    NotEqual,
    LessThan,
    GreaterThan,
    LessThanOrEqual,
    GreaterThanOrEqual,

    LogicalOr,
    LogicalAnd,
};

pub const Precedence = enum(u8) {
    Lowest = 0,
    Logical,
    Equality,
    Comparison,
    Sum,
    Product,
    Exponent,
    Prefix,
    Group,
};
