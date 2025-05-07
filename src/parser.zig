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

    pub fn parse(self: *Parser) !std.ArrayList(Expression) {
        var statements = std.ArrayList(Expression).init(self.alloc);
        errdefer statements.deinit();

        while (self.current_token().type != .Eof) {
            const expr = try self.parse_expression();
            try statements.append(expr);
        }

        return statements;
    }

    fn parse_expression(self: *Parser) anyerror!Expression {
        switch (self.current_token().type) {
            .IntLiteral => return try self.parse_int_literal(),
            else => return error.NoParseFunctionForTokenType,
        }
    }

    fn expect_int(self: *Parser) !i64 {
        switch (self.current_token().type) {
            .IntLiteral => |int| {
                self.advance();
                return int;
            },
            else => return error.ExpectedInt,
        }
    }

    fn parse_int_literal(self: *Parser) !Expression {
        return .{ .IntLiteral = try self.expect_int() };
    }

    fn advance(self: *Parser) void {
        self.current += 1;
    }

    fn current_token(self: *Parser) Token {
        if (self.current >= self.tokens.len) {
            return Token{ .type = .Eof, .pos = token.Span{ .start = 0, .size = 0 }, .line = self.line };
        }
        return self.tokens[self.current];
    }

    fn current_precedence(self: *Parser) Precedence {
        // gotta assign this to a variable bc poor little compiler gets confused ;(
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
