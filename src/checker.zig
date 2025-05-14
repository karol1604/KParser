const std = @import("std");
const ast = @import("ast.zig");
const utils = @import("utils.zig");
const span_ = @import("span.zig");

const Span = span_.Span;

const TypeId = u32;

const INT_TYPE_ID: TypeId = 0;
const BOOL_TYPE_ID: TypeId = 1;

const CheckedStatement = struct {
    expr: *const CheckedExpression,
};

pub const CheckedExpression = struct {
    type_id: TypeId,
    data: CheckedExpressionData,
};

const CheckedExpressionData = union(enum) {
    IntLiteral: i64,
    BoolLiteral: bool,
    Identifier: []const u8,

    Unary: struct {
        operator: ast.UnaryOperator,
        right: *const CheckedExpression,
    },

    Binary: struct {
        left: *const CheckedExpression,
        operator: ast.BinaryOperator,
        right: *const CheckedExpression,
    },
};

pub const Checker = struct {
    alloc: std.mem.Allocator,
    statements: []*const ast.Statement,

    pub fn init(alloc: std.mem.Allocator, stmts: []*const ast.Statement) Checker {
        return Checker{
            .alloc = alloc,
            .statements = stmts,
        };
    }

    fn make_pointer(self: *const Checker, comptime T: type, val: T) !*T {
        const ptr = try self.alloc.create(T);
        ptr.* = val;
        return ptr;
    }

    pub fn check(self: *Checker) !std.ArrayList(*CheckedStatement) {
        var checked_statements = std.ArrayList(*CheckedStatement).init(self.alloc);
        errdefer checked_statements.deinit();

        for (self.statements) |stmt| {
            const checked_stmt = try self.check_statement(stmt);
            try checked_statements.append(checked_stmt);
            // Do something with checked_stmt
        }

        return checked_statements;
    }

    fn check_statement(self: *Checker, stmt: *const ast.Statement) !*CheckedStatement {
        const expr = switch (stmt.*.kind) {
            ast.StatementKind.ExpressionStatement => |expr_stmt| try self.check_expression(expr_stmt, null),
            else => return error.NotYetImplemented,
        };

        return self.make_pointer(CheckedStatement, CheckedStatement{
            .expr = expr,
        });
    }

    fn check_expression(self: *Checker, expr: *const ast.Expression, type_hint: ?TypeId) !*CheckedExpression {
        switch (expr.*.kind) {
            .IntLiteral => |int| {
                return try self.typed_expression(.{ .IntLiteral = int }, expr.*.span, INT_TYPE_ID, type_hint);
            },
            .BoolLiteral => |b| {
                return try self.typed_expression(.{ .BoolLiteral = b }, expr.*.span, BOOL_TYPE_ID, type_hint);
            },

            .Unary => |unary| {
                switch (unary.operator) {
                    .Not => {
                        const right = try self.check_expression(unary.right, BOOL_TYPE_ID);
                        return try self.typed_expression(
                            .{ .Unary = .{
                                .operator = unary.operator,
                                .right = right,
                            } },
                            expr.*.span,
                            BOOL_TYPE_ID,
                            type_hint,
                        );
                    },
                    .Plus, .Minus => {
                        const right = try self.check_expression(unary.right, INT_TYPE_ID);
                        return try self.typed_expression(
                            .{ .Unary = .{
                                .operator = unary.operator,
                                .right = right,
                            } },
                            expr.*.span,
                            INT_TYPE_ID,
                            type_hint,
                        );
                    },
                }
            },

            .Binary => |binary| {
                switch (binary.operator) {
                    .Plus, .Minus, .Multiply, .Divide, .Exponent => {
                        const left = try self.check_expression(binary.left, INT_TYPE_ID);
                        const right = try self.check_expression(binary.right, INT_TYPE_ID);
                        return try self.typed_expression(
                            .{ .Binary = .{
                                .left = left,
                                .operator = binary.operator,
                                .right = right,
                            } },
                            expr.*.span,
                            INT_TYPE_ID,
                            type_hint,
                        );
                    },
                    .LessThan, .GreaterThan, .LessThanOrEqual, .GreaterThanOrEqual => {
                        const left = try self.check_expression(binary.left, INT_TYPE_ID);
                        const right = try self.check_expression(binary.right, INT_TYPE_ID);
                        return try self.typed_expression(
                            .{ .Binary = .{
                                .left = left,
                                .operator = binary.operator,
                                .right = right,
                            } },
                            expr.*.span,
                            BOOL_TYPE_ID,
                            type_hint,
                        );
                    },
                    .Equal, .NotEqual => {
                        const left = try self.check_expression(binary.left, null);
                        const right = try self.check_expression(binary.right, left.type_id);

                        return try self.typed_expression(
                            .{ .Binary = .{
                                .left = left,
                                .operator = binary.operator,
                                .right = right,
                            } },
                            expr.*.span,
                            BOOL_TYPE_ID,
                            type_hint,
                        );
                    },
                    .LogicalAnd, .LogicalOr => {
                        const left = try self.check_expression(binary.left, BOOL_TYPE_ID);
                        const right = try self.check_expression(binary.right, BOOL_TYPE_ID);

                        return try self.typed_expression(
                            .{ .Binary = .{
                                .left = left,
                                .operator = binary.operator,
                                .right = right,
                            } },
                            expr.*.span,
                            BOOL_TYPE_ID,
                            type_hint,
                        );
                    },
                    // else => {
                    //     return error.UnknownBinaryOperator;
                    // },
                }
            },
            else => {
                std.debug.print("Unknown expression type \n", .{});
                return error.UnknownExpressionType;
            },
        }
    }

    fn typed_expression(self: *Checker, res: CheckedExpressionData, span: Span, res_type: TypeId, type_hint: ?TypeId) !*CheckedExpression {
        if (type_hint) |hint| {
            if (res_type != hint) {
                std.debug.print("Type mismatch: expected type {d}, got {d} at {s}\n", .{ hint, res_type, span });
                return error.TypeMismatch;
            } else {
                return self.make_pointer(CheckedExpression, CheckedExpression{
                    .type_id = res_type,
                    .data = res,
                });
            }
        } else {
            return self.make_pointer(CheckedExpression, CheckedExpression{
                .type_id = res_type,
                .data = res,
            });
        }
    }
};
