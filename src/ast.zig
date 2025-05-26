const std = @import("std");
const span = @import("span.zig");

const Span = span.Span;

pub const FunctionParameter = struct {
    name: []const u8,
    type: []const u8,
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

    FunctionDeclaration: struct {
        parameters: std.ArrayList(*const FunctionParameter),
        returnType: ?*const Expression,
        body: std.ArrayList(*Expression),
    },

    VariableDeclaration: struct {
        name: []const u8,
        value: *const Expression,
        type: ?[]const u8,
    },

    Block: struct {
        body: std.ArrayList(*Expression),
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
