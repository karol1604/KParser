pub const TokenType = union(enum) {
    Plus,
    Minus,
    Star,
    Slash,
    Caret,

    LParen,
    RParen,
    LSquare,
    RSquare,
    LBrace,
    RBrace,

    Equal,
    NotEqual,
    LessThan,
    GreaterThan,
    LessThanOrEqual,
    GreaterThanOrEqual,

    DoubleEqual,

    Comma,
    Dot,
    Semicolon,

    Identifier: []const u8,
    IntLiteral: i64,
};

pub fn token_type_to_string(token_type: TokenType) []const u8 {
    switch (token_type) {
        .Plus => return "+",
        .Minus => return "-",
        .Star => return "*",
        .Slash => return "/",
        .Caret => return "^",
        .LParen => return "(",
        .RParen => return ")",
        .LSquare => return "[",
        .RSquare => return "]",
        .LBrace => return "{",
        .RBrace => return "}",
        .Equal => return "=",
        .NotEqual => return "!=",
        .LessThan => return "<",
        .GreaterThan => return ">",
        .LessThanOrEqual => return "<=",
        .GreaterThanOrEqual => return ">=",
        .DoubleEqual => return "==",
        .Comma => return ",",
        .Dot => return ".",
        .Semicolon => return ";",
        .Identifier => |name| return name,
        .IntLiteral => |_| return "IntLiteral",
    }
}

pub const Span = struct {
    start: usize,
    size: usize,
};

pub const Token = struct {
    type: TokenType,
    pos: Span,
    line: usize,
};
