const std = @import("std");

pub const Expression = union(enum) {
    IntLiteral: i64,

    Identifier: []const u8,

    Unary: struct {
        operator: UnaryOperator,
        epxression: *Expression,
    },

    Binary: struct {
        left: *Expression,
        operator: BinaryOperator,
        right: *Expression,
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
};

pub const Precedence = enum(u8) {
    Lowest = 0,
    Sum = 1,
    Product = 2,
    Exponent = 3,
    Group = 4,
};
