const std = @import("std");
const ast = @import("ast.zig");
const utils = @import("utils.zig");
const span_ = @import("span.zig");

const Span = span_.Span;

const TypeId = usize;

const EMPTY_TYPE_ID: TypeId = 0;
const INT_TYPE_ID: TypeId = 1;
const BOOL_TYPE_ID: TypeId = 2;

const CheckedStatement = struct {
    expr: *const CheckedExpression,
};

pub const CheckedExpression = struct {
    typeId: TypeId,
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

    VariableDeclaration: struct {
        name: []const u8,
        value: *const CheckedExpression,
    },
};

pub const Checker = struct {
    alloc: std.mem.Allocator,
    statements: []*ast.Statement,
    types: std.ArrayList([]const u8),

    pub fn init(alloc: std.mem.Allocator, stmts: []*ast.Statement) !Checker {
        var types = std.ArrayList([]const u8).init(alloc);
        errdefer types.deinit();
        try types.append("Empty");
        try types.append("Int");
        try types.append("Bool");

        return Checker{
            .alloc = alloc,
            .statements = stmts,
            .types = types,
        };
    }

    fn makePointer(self: *const Checker, comptime T: type, val: T) !*T {
        const ptr = try self.alloc.create(T);
        ptr.* = val;
        return ptr;
    }

    pub fn check(self: *Checker) !std.ArrayList(*CheckedStatement) {
        var checkedStatements = std.ArrayList(*CheckedStatement).init(self.alloc);
        errdefer checkedStatements.deinit();

        for (self.statements) |stmt| {
            const checkedStmt = try self.checkStatement(stmt);
            try checkedStatements.append(checkedStmt);
            // Do something with checkedStmt
        }

        return checkedStatements;
    }

    fn checkStatement(self: *Checker, stmt: *const ast.Statement) !*CheckedStatement {
        var expr: *const CheckedExpression = undefined;
        switch (stmt.*.kind) {
            ast.StatementKind.ExpressionStatement => |exprStmt| {
                expr = try self.checkExpression(exprStmt, null);
            },
            ast.StatementKind.VariableDeclaration => |varDecl| {
                const expectedType = self.lookupType(varDecl.type);

                // really?
                if (expectedType == null) {
                    if (varDecl.type) |typeName| {
                        std.debug.print("Unknown type `{s}` at {any}\n", .{ typeName, stmt.*.span });
                    }
                    return error.UnknownType;
                }

                const value = try self.checkExpression(varDecl.value, expectedType);
                expr = try self.typedExpression(.{
                    .VariableDeclaration = .{
                        .name = varDecl.name,
                        .value = value,
                    },
                }, stmt.*.span, EMPTY_TYPE_ID, null);
            },
            else => return error.NotYetImplemented,
        }

        return try self.makePointer(CheckedStatement, CheckedStatement{
            .expr = expr,
        });
    }

    fn lookupType(self: *Checker, name_: ?[]const u8) ?TypeId {
        if (name_) |name| {
            for (self.types.items, 0..) |typeName, index| {
                if (std.mem.eql(u8, typeName, name)) {
                    return @as(TypeId, index);
                }
            }
        }
        return null;
    }

    fn checkExpression(self: *Checker, expr: *const ast.Expression, typeHint: ?TypeId) !*CheckedExpression {
        switch (expr.*.kind) {
            .IntLiteral => |int| {
                return try self.typedExpression(.{ .IntLiteral = int }, expr.*.span, INT_TYPE_ID, typeHint);
            },
            .BoolLiteral => |b| {
                return try self.typedExpression(.{ .BoolLiteral = b }, expr.*.span, BOOL_TYPE_ID, typeHint);
            },

            .Unary => |unary| {
                switch (unary.operator) {
                    .Not => {
                        const right = try self.checkExpression(unary.right, BOOL_TYPE_ID);
                        return try self.typedExpression(
                            .{ .Unary = .{
                                .operator = unary.operator,
                                .right = right,
                            } },
                            expr.*.span,
                            BOOL_TYPE_ID,
                            typeHint,
                        );
                    },
                    .Plus, .Minus => {
                        const right = try self.checkExpression(unary.right, INT_TYPE_ID);
                        return try self.typedExpression(
                            .{ .Unary = .{
                                .operator = unary.operator,
                                .right = right,
                            } },
                            expr.*.span,
                            INT_TYPE_ID,
                            typeHint,
                        );
                    },
                }
            },

            .Binary => |binary| {
                switch (binary.operator) {
                    .Plus, .Minus, .Multiply, .Divide, .Exponent => {
                        const left = try self.checkExpression(binary.left, INT_TYPE_ID);
                        const right = try self.checkExpression(binary.right, INT_TYPE_ID);
                        return try self.typedExpression(
                            .{ .Binary = .{
                                .left = left,
                                .operator = binary.operator,
                                .right = right,
                            } },
                            expr.*.span,
                            INT_TYPE_ID,
                            typeHint,
                        );
                    },
                    .LessThan, .GreaterThan, .LessThanOrEqual, .GreaterThanOrEqual => {
                        const left = try self.checkExpression(binary.left, INT_TYPE_ID);
                        const right = try self.checkExpression(binary.right, INT_TYPE_ID);
                        return try self.typedExpression(
                            .{ .Binary = .{
                                .left = left,
                                .operator = binary.operator,
                                .right = right,
                            } },
                            expr.*.span,
                            BOOL_TYPE_ID,
                            typeHint,
                        );
                    },
                    .Equal, .NotEqual => {
                        const left = try self.checkExpression(binary.left, null);
                        const right = try self.checkExpression(binary.right, left.typeId);

                        return try self.typedExpression(
                            .{ .Binary = .{
                                .left = left,
                                .operator = binary.operator,
                                .right = right,
                            } },
                            expr.*.span,
                            BOOL_TYPE_ID,
                            typeHint,
                        );
                    },
                    .LogicalAnd, .LogicalOr => {
                        const left = try self.checkExpression(binary.left, BOOL_TYPE_ID);
                        const right = try self.checkExpression(binary.right, BOOL_TYPE_ID);

                        return try self.typedExpression(
                            .{ .Binary = .{
                                .left = left,
                                .operator = binary.operator,
                                .right = right,
                            } },
                            expr.*.span,
                            BOOL_TYPE_ID,
                            typeHint,
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

    fn typedExpression(self: *Checker, res: CheckedExpressionData, span: Span, resType: TypeId, typeHint: ?TypeId) !*CheckedExpression {
        if (typeHint) |hint| {
            if (resType != hint) {
                std.debug.print("Type mismatch: expected type {d}, got {d} at {s}\n", .{ hint, resType, span });
                return error.TypeMismatch;
            } else {
                return self.makePointer(CheckedExpression, CheckedExpression{
                    .typeId = resType,
                    .data = res,
                });
            }
        } else {
            return self.makePointer(CheckedExpression, CheckedExpression{
                .typeId = resType,
                .data = res,
            });
        }
    }
};
