const std = @import("std");
const token = @import("tokens.zig");
const ast = @import("ast.zig");

const Token = token.Token;
const TokenType = token.TokenType;
const Precedence = ast.Precedence;
const Expression = ast.Expression;

pub const Parser = struct {
    tokens: []const Token,
    alloc: std.mem.Allocator,
    current: usize = 0,
    line: usize = 1,

    pub fn init(tokens: []const Token, alloc: std.mem.Allocator) Parser {
        return Parser{ .tokens = tokens, .alloc = alloc };
    }

    pub fn deinit(self: *Parser) void {
        _ = self;
    }

    fn advance(self: *Parser) void {
        self.current += 1;
    }

    fn current_precedence(self: *Parser) Precedence {
        // gotta assign this to a variable bc poor little compiler gets confused :(
        const prec: Precedence = switch (self.current_token().type) {
            .Plus => .Sum,
            .Minus => .Sum,
            .Star => .Product,
            .Slash => .Product,
            .Caret => .Exponent,
            .LParen => .Group,
            else => .Lowest,
        };

        return prec;
    }
};
