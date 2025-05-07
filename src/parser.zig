const std = @import("std");
const token = @import("tokens.zig");
const ast = @import("ast.zig");

const Token = token.Token;
const TokenType = token.TokenType;

const Precedence = ast.Precedence;
const Expression = ast.Expression;
const BinaryOperator = ast.BinaryOperator;

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

    fn make_expression_pointer(self: *Parser, expr: Expression) !*Expression {
        const ptr = try self.alloc.create(Expression);
        ptr.* = expr;
        return ptr;
    }

    pub fn parse(self: *Parser) !std.ArrayList(*Expression) {
        var statements = std.ArrayList(*Expression).init(self.alloc);
        errdefer statements.deinit();

        while (self.current_token().type != .Eof) {
            const expr = try self.parse_expression(.Lowest);
            try statements.append(expr);
        }

        return statements;
    }

    fn parse_expression(self: *Parser, prec: Precedence) anyerror!*Expression {
        var expr = switch (self.current_token().type) {
            .IntLiteral => try self.parse_int_literal(),
            else => return error.NoParseFunctionForTokenType,
        };

        while (self.current_prec() > @intFromEnum(prec)) {
            switch (self.current_token().type) {
                .IntLiteral => return error.ConsecutiveInts, // TODO: this condition is actually never reached, fix this bug! (potentially replace > with >= but idk)
                .Plus => expr = try self.parse_binary_expression(expr, .Plus, .Sum),
                .Minus => expr = try self.parse_binary_expression(expr, .Minus, .Sum),
                .Star => expr = try self.parse_binary_expression(expr, .Multiply, .Product),
                .Slash => expr = try self.parse_binary_expression(expr, .Divide, .Product),
                .Caret => expr = try self.parse_binary_expression(expr, .Exponent, .Exponent),
                .Eof => return expr,
                else => return error.InvalidOperator,
            }
        }

        return expr;
    }

    fn parse_binary_expression(self: *Parser, lhs: *Expression, op: BinaryOperator, prec: Precedence) !*Expression {
        self.advance();
        const rhs = try self.parse_expression(prec);

        return self.make_expression_pointer(.{ .Binary = .{
            .left = lhs,
            .operator = op,
            .right = rhs,
        } });
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

    fn parse_int_literal(self: *Parser) !*Expression {
        return try self.make_expression_pointer(.{ .IntLiteral = try self.expect_int() });
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

    fn current_prec(self: *Parser) u8 {
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

        return @intFromEnum(prec);
    }
};
