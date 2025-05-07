const std = @import("std");

pub const Expression = union(enum) {
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
